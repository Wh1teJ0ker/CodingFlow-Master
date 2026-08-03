# Orchestrator Workflow Maintenance Guide

[中文](./README.md)

This directory maintains a collaboration workflow for the primary session, Coders, Reviewers, and Release QA. This document covers maintenance entry points, content layers, and change constraints only. The executable rules remain in `SKILL.md` and the process files it references.

## Content layers

README-related material in this directory has three distinct layers:

1. **Maintenance guides**: `README.md` and `README_EN.md`
   - Written for contributors who maintain this skill.
   - Identify the standard, templates, and maintenance checks.
   - Do not replace `SKILL.md` or serve as a project-specific example.
2. **Project README standard**: `references/README-STANDARD.md`
   - Defines required structure, bilingual links, status language, and quality requirements for target-project READMEs.
   - Serves as the shared review baseline.
3. **Copyable templates**: `assets/project-templates/README.md.template` and `assets/project-templates/README_EN.md.template`
   - Provide the Chinese primary template and its English counterpart.
   - Use generic placeholders only and contain no project identity.
   - After copying them into a target project, replace every placeholder and remove optional guidance that does not apply.

## Usage

1. Read [`references/README-STANDARD.md`](./references/README-STANDARD.md) and establish the project's real status, audience, and distribution method.
2. Copy the Chinese template to `README.md` in the target-project root.
3. Copy the English template to `README_EN.md` in the target-project root.
4. Fill both versions together, keeping headings, facts, commands, and links aligned.
5. Verify the language links at the top of each file.
6. Run each installation, verification, and build command before documenting it. Mark unverified or unreleased capabilities explicitly.

## Maintenance principles

- Chinese `README.md` is the target project's primary README; English `README_EN.md` is its corresponding translation. They must link to each other.
- The standard defines what must be true, the templates provide a starting structure, and a project instance records current facts.
- Templates must not imply that features, build artifacts, or release channels are already available.
- Commands must remain replaceable. Never place local usernames, absolute paths, repository identities, or credentials in a template.
- Add, remove, and reorder sections in both language templates together.
- Disclose privacy, security, limitations, and platform differences directly instead of replacing facts with marketing language.

## Maintenance checklist

- [ ] `README.md` and `README_EN.md` have valid reciprocal language links.
- [ ] The standard covers project overview, current status, Quick Start, basic verification, and essential links.
- [ ] The two templates have matching sections.
- [ ] Templates use generic placeholders only.
- [ ] Quick Start commands are reproducible in a clean environment; release and download links are real.
- [ ] Bilingual facts are consistent; no credentials, private addresses, or external project identities are present.
