sessioncheck::sessioncheck("error")
library(here)

library(tidyverse)
library(scales)
library(marquee)
library(glue)

library(brms)

library(ggdist)
library(marginaleffects)
library(posterior)
library(bayestestR)


# Data -------------------------------------------------------------------

dta_raw <- read_csv(
  here("data", "data.csv"),
  col_types = cols(
    brand = readr::col_factor(),
    YYYY_MM_DD = readr::col_date(format = "%Y_%m_%d"),
    id = readr::col_factor(),
    odd_color = readr::col_factor(levels = c("white", "pink")),
    odd_selected = readr::col_logical(),
    truth = readr::col_factor(levels = c("white", "pink")),
    response = readr::col_factor(levels = c("white", "pink"))
  )
)

table(dta_raw$odd_color)
table(dta_raw$truth)

# Model 1: Triangle Test  ---------------------------------------------------
# Can people identify the odd marshmallow out of three?
# Does it matter if the odd one out is white or pink?

## Fit -----------------------------

dta_triangle <- dta_raw |>
  group_by(odd_color) |>
  summarise(
    n = n(),
    n_correct = sum(odd_selected)
  )

# mod_triangle <- brm(
#   n_correct | trials(n) ~ odd_color,
#   data = dta_triangle,
#   family = binomial("logit"),

#   # setting reasonable priors
#   prior = set_prior("normal(0, 1)", class = "b") +
#     set_prior("normal(0, 1)", class = "Intercept"),

#   backend = "cmdstanr",
#   seed = 20260519
# )

# saveRDS(mod_triangle, file = here("models/mod_triangle.rds"))
mod_triangle <- readRDS(here("models/mod_triangle.rds"))

# check rhat and ESS values
summarize_draws(mod_triangle, default_convergence_measures())


## Post estimation analysis ---------------------------------------------

# marginal probability of correctly identifying the odd one out:
pr_triangle <- avg_predictions(
  mod_triangle,
  newdata = datagrid(n = 1, grid_type = "counterfactual")
) |>
  describe_posterior(
    centrality = "median",
    ci_method = "hdi",
    ci = 0.9,

    test = c("p_direction", "p_rope"),
    rope_range = (1 / 3) + c(-0.05, 0.05),
    null = 1 / 3
  )

# conditional probability of correctly identifying the odd one out,
# by type of odd one out:
pr_triangle_conditional <- avg_predictions(
  mod_triangle,
  newdata = datagrid(n = 1),
  variables = "odd_color"
)

pr_triangle_conditional |>
  describe_posterior(
    centrality = "median",
    ci_method = "hdi",
    ci = 0.9,

    test = c("p_direction", "p_rope"),
    rope_range = 1 / 3 + c(-0.05, 0.05),
    null = 1 / 3
  )

pr_triangle_conditional |>
  get_draws(shape = "rvar") |>
  ggplot(aes(xdist = rvar, y = odd_color)) +
  stat_slabinterval(
    aes(fill = odd_color),
    slab_color = "grey",
    .width = c(0.5, 0.9),
    point_interval = median_hdci
  ) +
  geom_vline(xintercept = 1 / 3, linetype = "dashed") +
  scale_x_continuous(
    expression("P(choose the odd one out)"),
    limits = c(0, 1),
    sec.axis = dup_axis(name = NULL, breaks = 1 / 3, labels = "Chance (1/3)")
  ) +
  scale_y_discrete(NULL, labels = str_to_title) +
  coord_cartesian(ylim = c(1.5, 2.5)) +
  scale_fill_manual(
    values = c("white" = "grey95", "pink" = "#ff5e79"),
    guide = "none"
  ) +
  labs(
    title = "The Triangle Test",
    subtitle = paste(
      "Can people correctly identify the
      ***{.#ff5e79 odd}-{.#636363 colored}-{.#ff5e79 marshmallow}*** in a blind
       taste test?",

      "It seems like people can - performing above chance (1/3): ",
      format(pr_triangle) |>
        glue_data("Md = {Median}, 90% HDI {`90% CI`}, pd = {pd}."),

      "But they seem to be better at doing this when the odd one out is
      {.#ff5e79 pink} than when it's {.#636363 white}..."
    )
  ) +
  theme_bw() +
  theme(plot.subtitle = element_marquee(width = 1))


ggsave(
  here("outputs", "fig-triangle.png"),
  width = 6,
  height = 5,
  units = "in",
  scaling = 0.8,
  dpi = 600
)

# Model 2: SDT of Color --------------------------------------------------
# Can people guess the color of a single marshmallow?

## Fit ------------------------------------

dta_sdt <- dta_raw |>
  group_by(truth, response) |>
  summarise(
    n = n()
  )

# mod_sdt <- brm(
#   response | weights(n) ~ 0 + Intercept + truth,
#   data = dta_sdt,
#   family = bernoulli("probit"),

#   # setting reasonable priors
#   prior = set_prior("normal(0, 1)", coef = "Intercept") +
#     set_prior("normal(0, 1)", coef = "truthpink"),

#   backend = "cmdstanr",
#   seed = 20260519
# )

# saveRDS(mod_sdt, here("models/mod_sdt.rds"))
mod_sdt <- readRDS(here("models/mod_sdt.rds"))

# check rhat and ESS values
summarize_draws(mod_sdt, default_convergence_measures())


## Post estimation analysis ---------------------------------------------

# The simple probit model's parameters can be interpreted in terms of signal
# detection theory (SDT):
# - The intercept corresponds to the criterion (c)
# - The truthpink coefficient corresponds to the sensitivity (d')

draws_sdt <- mod_sdt |>
  as_draws_rvars() |>
  mutate_variables(
    criterion = -b_Intercept,
    bias = criterion - (b_truthpink / 2)
  )

### d' ------------------------------------
dta_dprime <- describe_posterior(
  draws_sdt$b_truthpink,

  centrality = "median",
  ci_method = "hdi",
  ci = 0.9,

  test = c("p_direction", "p_rope"),
  rope_range = c(-Inf, 0.15),
  null = 0
)


### c ------------------------------------
describe_posterior(
  draws_sdt$criterion,

  centrality = "median",
  ci_method = "hdi",
  ci = 0.9,

  test = NULL
)

dta_bias <- describe_posterior(
  draws_sdt$bias,

  centrality = "median",
  ci_method = "hdi",
  ci = 0.9,

  test = c("p_direction", "p_rope"),
  rope_range = c(-0.15, 0.15),
  null = 0
)


### plot ---------------------------------

# random draws from the distribution of perceptual evidence for the two types of
# marshmallows:
dta_dprime_ci <- expand_grid(
  x = seq(-4, 4, length.out = 100),
  mu = draws_of(draws_sdt$b_truthpink)
) |>
  mutate(
    d = dnorm(x, mean = mu, sd = 1)
  ) |>
  curve_interval(d, .along = x, .width = 0.9)

# scaling factor to make the S+N distribution fit nicely in the plot
s <- 0.9 / max(dta_dprime_ci$d)


ggplot() +
  # Singal+Noise distribution (pink marshmallow):
  geom_lineribbon(
    aes(
      x,
      d * s,
      ymin = .lower * s,
      ymax = .upper * s,
      fill = "pink",
      color = "pink"
    ),
    data = dta_dprime_ci,
    alpha = 0.7,
    linewidth = 1.5
  ) +
  # Noise distribution (white marshmallow):
  stat_slab(
    aes(xdist = distributional::dist_normal(), color = "white"),
    linewidth = 1.5,
    fill = NA
  ) +
  scale_fill_manual(
    "Marshmallow",
    values = c("white" = "grey20", "pink" = "#ff5e79"),
    labels = c("white" = "White (Noise)", "pink" = "Pink"),
    aesthetics = c("fill", "color"),
    guide = guide_legend(
      order = 1,
      override.aes = list(fill = c("#ff5e79", "white"))
    )
  ) +
  # The criterion (c):
  ggnewscale::new_scale_color() +
  ggnewscale::new_scale_fill() +
  stat_gradientinterval(
    aes(
      xdist = draws_sdt$criterion,
      fill = "Criterion (c)",
      color = "Criterion (c)"
    ),
    scale = 1,
    side = "top",
    justification = 0,
  ) +
  scale_color_manual(
    NULL,
    values = c("Criterion (c)" = "grey50"),
    guide = guide_legend(order = 2),
    aesthetics = c("color", "fill")
  ) +
  # Theme and labels:
  theme_bw() +
  theme_sub_axis_y(
    title = element_blank(),
    text = element_blank(),
    ticks = element_blank()
  ) +
  theme(
    plot.subtitle = element_marquee(
      width = 1.22,
      margin = margin(b = 25)
    ),
    plot.title = element_marquee(width = 1)
  ) +
  labs(
    x = expression(paste(Phi^-1, "(p), Perceptual evidence")),
    title = 'Signal Detection Theory of {.#ff5e79 "Color"} Perception',

    subtitle = paste(
      "Can people reliably *identify* the {.#ff5e79 **pink marshmallow**} from
      the {.#636363 **white marshmallow**}?  ",

      "Using Signal Detection Theory (SDT), *discriminability* is conceptualized
       as the distance (*d'*) of the distribution of perceptual evidence for the
       {.#ff5e79 **pink marshmallow**} (**Signal+Noise**) from the distribution
       of perceptual evidence for the {.#636363 **white marshmallow**} (**Noise**,
       fixed at N(0, 1)).",
      format(dta_dprime) |>
        glue_data(
          "There's a posterior probability {pd} that they can,",
          "but there's also a posterior probability of {`p (ROPE)`} that discriminability is less than 0.15..."
        ),
      format(dta_bias) |>
        glue_data(
          "Looking at the criterion (*c*), the data suggests (pd = <pd>) a small but maybe unsubstantial bias towards responding {.#ff5e79 pink}
          (p(ROPE) = <`p (ROPE)`>).",
          .open = "<",
          .close = ">"
        ),
      sep = "\n"
    )
  )

ggsave(
  here("outputs", "fig-sdt.png"),
  width = 6,
  height = 5,
  units = "in",
  scaling = 0.8,
  dpi = 600
)
