# subtitle-selection Specification

## Purpose

TBD - created by archiving change 'add-clear-all-subtitles'. Update Purpose after archive.

## Requirements

### Requirement: Clear all selected subtitles

When subtitle choices are displayed, the system SHALL provide a control labeled "全部取消" that clears every selected subtitle without dismissing the media selection view. Activating this control SHALL NOT change the selected audio track.

#### Scenario: Clear the default subtitle selection

- **WHEN** the media selection view initially has multiple subtitle languages selected and the user activates "全部取消"
- **THEN** the system SHALL leave every subtitle language unselected and keep the media selection view open

##### Example: Keep only one of three subtitles

- **GIVEN** `zh-TW`, `en`, and `ja` subtitles are selected by default
- **WHEN** the user activates "全部取消" and then selects `en`
- **THEN** only the `en` subtitle SHALL be selected for download

#### Scenario: Preserve the selected audio track

- **WHEN** the user has selected an audio track and activates "全部取消" in the subtitle section
- **THEN** the system SHALL preserve the selected audio track unchanged


<!-- @trace
source: add-clear-all-subtitles
updated: 2026-07-13
code:
  - .agents/skills/spectra-commit/SKILL.md
  - .agents/skills/spectra-propose-plus/SKILL.md
  - .agents/skills/spectra-apply-plus/SKILL.md
  - Tubify/Views/MediaSelectionView.swift
  - .agents/skills/spectra-verify/SKILL.md
  - TubifyTests/MediaSelectionLogicTests.swift
  - .agents/skills/spectra-analyze/SKILL.md
-->

---
### Requirement: Preserve default subtitle selection

The system SHALL continue to select all supported subtitle languages when the media selection view first appears.

#### Scenario: Open media selection with supported subtitles

- **WHEN** the media selection view appears with supported subtitle languages available
- **THEN** the system SHALL initially select every supported subtitle language

<!-- @trace
source: add-clear-all-subtitles
updated: 2026-07-13
code:
  - .agents/skills/spectra-commit/SKILL.md
  - .agents/skills/spectra-propose-plus/SKILL.md
  - .agents/skills/spectra-apply-plus/SKILL.md
  - Tubify/Views/MediaSelectionView.swift
  - .agents/skills/spectra-verify/SKILL.md
  - TubifyTests/MediaSelectionLogicTests.swift
  - .agents/skills/spectra-analyze/SKILL.md
-->