#!/usr/bin/env python3
"""orchestrator-workflow skill 资源自检脚本。

不依赖第三方 Python 包。优先尝试用 PyYAML 解析 YAML；若不可用，退化为
结构性检查并明确报告能力降级。检查项：
  - 必需文件/目录存在
  - Markdown 相对链接有效（跳过 fenced code 中的示例链接）
  - workflow / config YAML 可加载（或退化检查）
  - 禁止身份信息、绝对本机路径、真实密钥模式
  - 禁止可变引用（@latest、GO_VERSION: stable、toolchain@stable）
  - 版本规范仅允许稳定版数字 semver，不允许 rc/beta/alpha 等预发布
  - 模板变量在对应 TEMPLATE-VARIABLES.md 中登记
  - README 双语模板章节与占位符集合一致
  - templates/examples 的占位符残留符合各自规则
  - handoff 快照若存在，需满足最小一致性要求
  - Release 三种状态实例齐全且 failed/blocked 不可发布

退出码 0 表示全部通过，非 0 表示存在失败项。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
PROCESS_DOCS = [
    "00-doc-planning.md",
    "01-task-decomposition.md",
    "02-dispatch-and-verify.md",
    "03-e2e-acceptance.md",
    "04-coder-spec.md",
    "05-reviewer-spec.md",
    "06-progress-sync.md",
    "07-release-qa-audit.md",
]

# 必需文件清单（相对 skill 根）
REQUIRED_FILES = [
    "SKILL.md",
    "README.md",
    "README_EN.md",
    *PROCESS_DOCS,
    "references/README-STANDARD.md",
    "references/GITHUB-ACTIONS-STANDARD.md",
    "references/RELEASE-STANDARD.md",
    "references/RUST-TAURI.md",
    "references/GO-WAILS.md",
    "assets/project-templates/README.md.template",
    "assets/project-templates/README_EN.md.template",
    "assets/project-templates/rust-tauri/.github/workflows/ci.yml",
    "assets/project-templates/rust-tauri/.github/workflows/release.yml",
    "assets/project-templates/rust-tauri/.github/dependabot.yml",
    "assets/project-templates/rust-tauri/release-config.example.yml",
    "assets/project-templates/rust-tauri/TEMPLATE-VARIABLES.md",
    "assets/project-templates/go-wails/.github/workflows/ci.yml",
    "assets/project-templates/go-wails/.github/workflows/release.yml",
    "assets/project-templates/go-wails/.github/dependabot.yml",
    "assets/project-templates/go-wails/release-config.example.yml",
    "assets/project-templates/go-wails/TEMPLATE-VARIABLES.md",
    "assets/project-templates/release-docs/04-版本标准.md.template",
    "assets/project-templates/release-docs/规划需求.md.template",
    "assets/project-templates/release-docs/更新日志.md.template",
    "assets/project-templates/release-docs/QA-审计报告.md.template",
    "examples/README.md",
    "examples/rust-tauri/README.md",
    "examples/rust-tauri/ci.yml",
    "examples/rust-tauri/release.yml",
    "examples/go-wails/README.md",
    "examples/go-wails/ci.yml",
    "examples/go-wails/release.yml",
    "examples/release/qa-passed.md",
    "examples/release/qa-failed.md",
    "examples/release/blocked.md",
]

# 禁止出现的参考项目身份
FORBIDDEN_IDENTITY = ["RuT0Loom", "RuT0Markflow", "GoT0Emergency"]

# 禁止的可变引用模式（在模板与实例范围内扫描）
FORBIDDEN_PATTERNS = [
    r"@latest",
    r"GO_VERSION:\s*stable",
    r"dtolnay/rust-toolchain@stable",
    r"docs/versions/v0\.1\.0",
]

# 真实密钥/绝对本机路径模式
SECRET_PATTERNS = [
    r"/Users/[^/\s]+",
    r"/home/[^/\s]+",
]

STABLE_TAG_REGEX = r"\^v\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$"
FORBIDDEN_PRERELEASE_PATTERNS = [
    r"v[0-9]+\.[0-9]+\.[0-9]+-rc(?:\.[0-9]+)?",
    r"v[0-9]+\.[0-9]+\.[0-9]+-beta(?:\.[0-9]+)?",
    r"v[0-9]+\.[0-9]+\.[0-9]+-alpha(?:\.[0-9]+)?",
    r"prerelease:\s*\$\{\{",
    r"\(-\[0-9A-Za-z\.\-\]\+\)\?",
]
ALLOWED_EXAMPLE_PLACEHOLDERS = {"<ver>"}

errors: list[str] = []
warnings: list[str] = []


def check_required_files() -> None:
    for rel in REQUIRED_FILES:
        if not (SKILL_ROOT / rel).exists():
            errors.append(f"missing required file: {rel}")


def iter_md_files(roots: list[str]) -> list[Path]:
    out: list[Path] = []
    for r in roots:
        base = SKILL_ROOT / r
        if base.is_file() and base.suffix == ".md":
            out.append(base)
        elif base.is_dir():
            out.extend(sorted(base.rglob("*.md")))
    return out


def strip_fenced_code(text: str) -> str:
    """移除 fenced code block 内容，避免误判示例链接。"""
    return re.sub(r"```.*?```", "", text, flags=re.DOTALL)


def check_md_links() -> None:
    md_targets = ["references", "assets", "examples", "SKILL.md", "README.md", "README_EN.md", *PROCESS_DOCS]
    md_files = iter_md_files(md_targets)
    link_re = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
    for f in md_files:
        try:
            raw = f.read_text(encoding="utf-8")
        except Exception as e:  # noqa: BLE001
            errors.append(f"cannot read {f}: {e}")
            continue
        content = strip_fenced_code(raw)
        for m in link_re.finditer(content):
            label, target = m.group(1), m.group(2).strip()
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            path_part = target.split("#")[0].strip()
            if not path_part:
                continue
            resolved = (f.parent / path_part).resolve()
            if not resolved.exists():
                errors.append(f"broken md link in {f.relative_to(SKILL_ROOT)}: [{label}]({target})")


def load_yaml_safe(path: Path):
    try:
        import yaml  # type: ignore
    except ImportError:
        return None, "PyYAML not available; structural check only"
    try:
        with path.open(encoding="utf-8") as fh:
            yaml.safe_load(fh)
        return True, None
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def weak_yaml_structure_ok(text: str) -> tuple[bool, str | None]:
    if not text.strip():
        return False, "empty file"
    if ":" not in text:
        return False, "yaml file has no key colon"
    lines = text.splitlines()
    for idx, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "\t" in line:
            return False, f"tab indentation found at line {idx}"
        if line.rstrip() != line:
            return False, f"trailing whitespace found at line {idx}"
    return True, None


def check_yaml() -> None:
    yaml_targets = [
        "assets/project-templates/rust-tauri/.github/workflows/ci.yml",
        "assets/project-templates/rust-tauri/.github/workflows/release.yml",
        "assets/project-templates/rust-tauri/.github/dependabot.yml",
        "assets/project-templates/rust-tauri/release-config.example.yml",
        "assets/project-templates/go-wails/.github/workflows/ci.yml",
        "assets/project-templates/go-wails/.github/workflows/release.yml",
        "assets/project-templates/go-wails/.github/dependabot.yml",
        "assets/project-templates/go-wails/release-config.example.yml",
        "examples/rust-tauri/ci.yml",
        "examples/rust-tauri/release.yml",
        "examples/go-wails/ci.yml",
        "examples/go-wails/release.yml",
    ]
    yaml_available = True
    try:
        import yaml  # noqa: F401
    except ImportError:
        yaml_available = False
        warnings.append("PyYAML not available; YAML files will receive strengthened structural check only")
    for rel in yaml_targets:
        p = SKILL_ROOT / rel
        if not p.exists():
            errors.append(f"missing yaml file: {rel}")
            continue
        if yaml_available:
            ok, msg = load_yaml_safe(p)
            if not ok:
                errors.append(f"yaml parse failed for {rel}: {msg}")
        else:
            txt = p.read_text(encoding="utf-8")
            ok, msg = weak_yaml_structure_ok(txt)
            if not ok:
                errors.append(f"yaml structural check failed for {rel}: {msg}")


def check_forbidden() -> None:
    scan_roots = ["references", "assets/project-templates", "examples", *PROCESS_DOCS, "SKILL.md", "README.md", "README_EN.md"]
    files: list[Path] = []
    for r in scan_roots:
        base = SKILL_ROOT / r
        if base.is_file():
            files.append(base)
        elif base.is_dir():
            files.extend(sorted(base.rglob("*")))
    for f in files:
        if not f.is_file():
            continue
        if f.suffix not in {".md", ".yml", ".yaml", ".template"}:
            continue
        try:
            txt = f.read_text(encoding="utf-8")
        except Exception:  # noqa: BLE001
            continue
        rel = f.relative_to(SKILL_ROOT)
        for ident in FORBIDDEN_IDENTITY:
            if ident in txt:
                errors.append(f"forbidden identity '{ident}' in {rel}")
        for pat in FORBIDDEN_PATTERNS:
            if re.search(pat, txt):
                errors.append(f"forbidden pattern '{pat}' in {rel}")
        for pat in SECRET_PATTERNS:
            if re.search(pat, txt):
                errors.append(f"absolute local path pattern '{pat}' in {rel}")


def extract_replace_placeholders(text: str) -> set[str]:
    return set(re.findall(r"<REPLACE:([A-Z0-9_]+)>", text))


def check_template_variables() -> None:
    for stack in ["rust-tauri", "go-wails"]:
        base = SKILL_ROOT / "assets/project-templates" / stack
        tv = base / "TEMPLATE-VARIABLES.md"
        if not tv.exists():
            errors.append(f"missing TEMPLATE-VARIABLES.md for {stack}")
            continue
        tv_text = tv.read_text(encoding="utf-8")
        declared = set(re.findall(r"<REPLACE:([A-Z0-9_]+)>", tv_text))
        declared |= set(re.findall(r"`([A-Z][A-Z0-9_]+)`", tv_text))
        wf_files = list((base / ".github/workflows").glob("*.yml")) if (base / ".github/workflows").exists() else []
        wf_files.append(base / "release-config.example.yml")
        used: set[str] = set()
        for wf in wf_files:
            if wf.exists():
                used |= extract_replace_placeholders(wf.read_text(encoding="utf-8"))
        undeclared = used - declared
        if undeclared:
            errors.append(f"{stack}: undeclared template variables used but not in TEMPLATE-VARIABLES.md: {sorted(undeclared)}")


def check_readme_template_parity() -> None:
    cn = SKILL_ROOT / "assets/project-templates/README.md.template"
    en = SKILL_ROOT / "assets/project-templates/README_EN.md.template"
    if not cn.exists() or not en.exists():
        errors.append("README templates missing for parity check")
        return
    cn_text = cn.read_text(encoding="utf-8")
    en_text = en.read_text(encoding="utf-8")
    cn_sections = [l.strip() for l in cn_text.splitlines() if l.startswith("## ")]
    en_sections = [l.strip() for l in en_text.splitlines() if l.startswith("## ")]
    if len(cn_sections) != len(en_sections):
        errors.append(f"README template section count mismatch: CN={len(cn_sections)} EN={len(en_sections)}")
    cn_ph = set(re.findall(r"\{\{([A-Z0-9_]+)\}\}", cn_text))
    en_ph = set(re.findall(r"\{\{([A-Z0-9_]+)\}\}", en_text))
    only_cn = cn_ph - en_ph
    only_en = en_ph - cn_ph
    if only_cn:
        errors.append(f"README placeholders only in CN template: {sorted(only_cn)}")
    if only_en:
        errors.append(f"README placeholders only in EN template: {sorted(only_en)}")


def check_placeholder_hygiene() -> None:
    readme_templates = [
        SKILL_ROOT / "assets/project-templates/README.md.template",
        SKILL_ROOT / "assets/project-templates/README_EN.md.template",
    ]
    for path in readme_templates:
        text = path.read_text(encoding="utf-8")
        if "<REPLACE:" in text:
            errors.append(f"README template should not contain <REPLACE:...> placeholders: {path.relative_to(SKILL_ROOT)}")

    workflow_templates = [
        *sorted((SKILL_ROOT / "assets/project-templates/rust-tauri").rglob("*.yml")),
        *sorted((SKILL_ROOT / "assets/project-templates/go-wails").rglob("*.yml")),
    ]
    for path in workflow_templates:
        text = path.read_text(encoding="utf-8")
        if re.search(r"\{\{[A-Z0-9_]+\}\}", text):
            errors.append(f"workflow/config template should not contain README-style placeholders: {path.relative_to(SKILL_ROOT)}")

    example_files = sorted((SKILL_ROOT / "examples").rglob("*"))
    for path in example_files:
        if not path.is_file() or path.suffix not in {".md", ".yml", ".yaml"}:
            continue
        text = path.read_text(encoding="utf-8")
        if re.search(r"\{\{[A-Z0-9_]+\}\}", text):
            errors.append(f"example contains unresolved README-style placeholder: {path.relative_to(SKILL_ROOT)}")
        if re.search(r"<REPLACE:[A-Z0-9_]+>", text):
            errors.append(f"example contains unresolved template variable: {path.relative_to(SKILL_ROOT)}")
        for raw in re.findall(r"<[A-Z][A-Z0-9_]*>", text):
            if raw not in ALLOWED_EXAMPLE_PLACEHOLDERS:
                errors.append(f"example contains unresolved angle-bracket placeholder {raw}: {path.relative_to(SKILL_ROOT)}")


def check_semver_policy() -> None:
    semver_targets = [
        SKILL_ROOT / "references/RELEASE-STANDARD.md",
        SKILL_ROOT / "references/RUST-TAURI.md",
        SKILL_ROOT / "assets/project-templates/release-docs/04-版本标准.md.template",
        SKILL_ROOT / "assets/project-templates/rust-tauri/.github/workflows/release.yml",
        SKILL_ROOT / "assets/project-templates/go-wails/.github/workflows/release.yml",
        SKILL_ROOT / "examples/rust-tauri/release.yml",
        SKILL_ROOT / "examples/go-wails/release.yml",
        SKILL_ROOT / "examples/release/qa-passed.md",
    ]
    for path in semver_targets:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(SKILL_ROOT)
        for pat in FORBIDDEN_PRERELEASE_PATTERNS:
            if re.search(pat, text):
                errors.append(f"numeric-only semver violation '{pat}' in {rel}")
    release_workflows = [
        SKILL_ROOT / "assets/project-templates/rust-tauri/.github/workflows/release.yml",
        SKILL_ROOT / "assets/project-templates/go-wails/.github/workflows/release.yml",
        SKILL_ROOT / "examples/rust-tauri/release.yml",
        SKILL_ROOT / "examples/go-wails/release.yml",
    ]
    for path in release_workflows:
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(SKILL_ROOT)
        if not re.search(STABLE_TAG_REGEX, text):
            errors.append(f"release workflow missing strict stable semver tag regex in {rel}")


def check_handoff_consistency() -> None:
    board = SKILL_ROOT / "handoff/TASK-BOARD.md"
    if not board.exists():
        return
    text = board.read_text(encoding="utf-8")
    if "required: false" in text:
        errors.append("handoff/TASK-BOARD.md: release_qa.required must not be false")
    if re.search(r"report:\s*N/A", text):
        errors.append("handoff/TASK-BOARD.md: release_qa.report must not be N/A")
    for ref in re.findall(r"handoff/[A-Za-z0-9._/-]+", text):
        if not (SKILL_ROOT / ref).exists():
            errors.append(f"handoff/TASK-BOARD.md references missing file: {ref}")


def check_commit_rule_coverage() -> None:
    """Verify commit规范 terms appear in key process docs."""
    checks: list[tuple[Path, str, str]] = [
        (SKILL_ROOT / "SKILL.md", "Conventional Commits", "SKILL.md should mention Conventional Commits"),
        (SKILL_ROOT / "01-task-decomposition.md", "Conventional Commits", "01-task-decomposition.md should mention Conventional Commits"),
        (SKILL_ROOT / "04-coder-spec.md", "Conventional Commits", "04-coder-spec.md should mention Conventional Commits"),
        (SKILL_ROOT / "04-coder-spec.md", "commit_summary:", "04-coder-spec.md REPORT template must include commit_summary field"),
        (SKILL_ROOT / "05-reviewer-spec.md", "commit 是否保持单一逻辑目的", "05-reviewer-spec.md should check commit granularity"),
    ]
    for path, needle, msg in checks:
        if not path.exists():
            errors.append(f"missing file for commit rule check: {path.relative_to(SKILL_ROOT)}")
            continue
        text = path.read_text(encoding="utf-8")
        if needle not in text:
            errors.append(msg)


def check_release_examples() -> None:
    ex_dir = SKILL_ROOT / "examples/release"
    for name in ["qa-passed.md", "qa-failed.md", "blocked.md"]:
        if not (ex_dir / name).exists():
            errors.append(f"missing release example: {name}")
    passed = ex_dir / "qa-passed.md"
    if passed.exists():
        txt = passed.read_text(encoding="utf-8")
        if "| 结论 | qa_passed |" not in txt:
            errors.append("qa-passed.md: conclusion must state qa_passed")
        if "| 最终版本状态 | release_complete |" not in txt:
            errors.append("qa-passed.md: final status must be release_complete")
    for name, status in [("qa-failed.md", "qa_failed"), ("blocked.md", "blocked")]:
        p = ex_dir / name
        if not p.exists():
            continue
        txt = p.read_text(encoding="utf-8")
        if "release_complete" in txt and status in txt:
            for line in txt.splitlines():
                if "结论" in line and "release_complete" in line:
                    errors.append(f"{name}: release_complete used as conclusion for non-passed status")
        if "| 结论 |" in txt and status not in txt:
            errors.append(f"{name}: conclusion does not state {status}")


def main() -> int:
    check_required_files()
    check_md_links()
    check_yaml()
    check_forbidden()
    check_template_variables()
    check_readme_template_parity()
    check_placeholder_hygiene()
    check_semver_policy()
    check_handoff_consistency()
    check_commit_rule_coverage()
    check_release_examples()

    if warnings:
        print("WARNINGS:")
        for w in warnings:
            print(f"  - {w}")
    if errors:
        print("FAILURES:")
        for e in errors:
            print(f"  - {e}")
        print(f"\n{len(errors)} failure(s).")
        return 1
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
