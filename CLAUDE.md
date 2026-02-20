# Promptbook -- an R package for documented, reproducible, reusable data annotation with LLMs

My idea with promptbook is that data annotation with LLMs in R need a package that's well suited for research workflows. The typical case is when a researcher has a dataset with text snippets that should be coded with a coding instrument. The text snippets might be abstracts for journal articles, newspaper headlines, curricula in different countries, etc. The coding instrument is how to assign several codes (categorical or numeric or other) to each text snippet. There may be many codes, both 5 and 20 will be common. The researcher will typically have humans code parts of the data, possibly a frontier language model as well, and then have a lesser language model code the rest of the data. Promptbook must help the researcher

- make a codebook with information enough to assign the codes for a human coder
- have a "promptbook" with the LLM prompt (together with tool usage, answer format, etc.) for an LLM to assign the codes
- a way to apply the promptbook to a dataset using `ellmer::`, either batched, in parallell, local, or otherwise.

Requirements:

- promptbook can generate a human readable codebook, maybe with codebookr or another backend
- promptbook is stored in a standard format as one or more files
- promptbook can very easily be applied to data with ellmer

# Target users

The primary audience is researchers who are novice-to-intermediate R programmers (e.g., social scientists, communication scholars). This should steer all design and scope decisions: the API must be simple, discoverable, and forgiving. Prefer fewer functions with clear names over flexible-but-complex interfaces.

# Scope

The project scope is defined in `design/01_scope.md`. The YAML schema is defined in `design/02_yaml_schema.md`. Key decisions:

- The YAML file is the single source of truth for the coding instrument
- `pb_annotate()` handles variable grouping, per-model dispatch, and result reassembly
- Power users can use `pb_type()` and the system prompt directly with ellmer
- Variable grouping is needed to stay within structured output limits (~24 params) and to support per-variable model assignment
- Five variable types: `categorical`, `numeric`, `text`, `boolean`, `object` (with `multiple: true` for arrays of categorical/text/object)
- `required` defaults to `false` to prevent LLM hallucination on missing data
- Out of scope: workflow orchestration, caching, retry logic, inter-rater reliability metrics

# Human learner

The human wants to be in the loop, as it is learning good package development practices, design practices, etc. 

# Chainlink

Work on only one chainlink issue at the time before handing over control to the user, unless told to do otherwise.

# Package conventions

Use R package conventions from devtools::, usethis::, and testthat::.

Aim for few dependencies; try to avoid depending on the tidyverse. (But the package user interface can very well use native pipe!)
