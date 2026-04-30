# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- Add pb_use_template() helper to copy starter promptbook YAML into user's project (#30)
- Add a starter promptbook YAML template at inst/templates/promptbook.yaml (#29)
- Update model aliases from provider-specific to semantic names (#25)
- Survey other languages for similar packages and evaluate porting vs designing from scratch (#3)
- Assess whether promptbook R package is redundant with existing tools (#2)

### Fixed

### Changed
- Verify full test suite passes after haven install (#31)
- Update model aliases from provider-specific (`haiku`/`sonnet`) to semantic names (`fast`/`strong`) (#25)
- Write package documentation and vignettes (#24)
- Implement pb_render() (#23)
- Implement pb_as_labelled() (#22)
- Result reassembly and column typing (#21)
- Prompt interpolation and ellmer dispatch (#20)
- Variable grouping and per-model dispatch logic (#19)
- Implement pb_annotate() (#18)
- Implement pb_type() (#15)
- Validate groups and cross-references (#14)
- Validate type-specific fields (#13)
- Validate required fields and top-level structure (#12)
- YAML parsing and promptbook S3 class (#11)
- Implement read_promptbook() (#10)
- Set up package skeleton (DESCRIPTION, namespace, testthat) (#9)
- Define package infrastructure (#6)
- Design the codebook renderer (#5)
- Design the ellmer bridge (#4)
- Design the user-facing API (#3)
- Design the YAML schema (#2)
- Add column typing and haven-labelled output to scope and schema design (#8)
- Add array/multiple-value support to YAML schema design (#7)
- Define project scope and boundaries (#1)
