#' @description
#' Define coding instruments as structured YAML files and apply them to
#' datasets using large language models via ellmer. The YAML file --- the
#' "promptbook" --- is the single source of truth: it generates both
#' human-readable codebooks and structured LLM prompts.
#'
#' ## Key functions
#'
#' - [read_promptbook()] reads and validates a YAML file
#' - [pb_annotate()] annotates a data frame using LLMs
#' - [pb_type()] converts a promptbook to an ellmer type object
#' - [pb_render()] renders a human-readable codebook (HTML or PDF)
#' - [pb_as_labelled()] converts results to SPSS/Stata format
#'
#' @seealso
#' - `vignette("promptbook")` for a getting-started guide
#' - `vignette("ellmer")` for power-user workflows with ellmer
#'
#' @keywords internal
"_PACKAGE"
