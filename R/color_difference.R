#' Calculate CIEDE2000 color differences
#'
#' Computes the CIEDE2000 color difference (Delta E 00) between corresponding
#' pairs of CIELAB coordinates. Inputs are vectorized, and length-one inputs
#' are recycled to the length of the longest input.
#'
#' @param l1,a1,b1 CIELAB coordinates for the reference colors.
#' @param l2,a2,b2 CIELAB coordinates for the comparison colors.
#' @param k_l,k_c,k_h Positive parametric weighting factors for lightness,
#'   chroma, and hue, respectively. The default value of `1` for each factor
#'   represents the reference viewing conditions defined for CIEDE2000.
#'
#' @return A numeric vector of CIEDE2000 color differences. Missing coordinate
#'   values produce missing results.
#'
#' @references
#' Sharma, G., Wu, W., & Dalal, E. N. (2005). The CIEDE2000 color-difference
#' formula: Implementation notes, supplementary test data, and mathematical
#' observations. *Color Research & Application, 30*(1), 21–30.
#' \doi{10.1002/col.20070}
#'
#' @examples
#' delta_e_2000(
#'   l1 = 50, a1 = 2.6772, b1 = -79.7751,
#'   l2 = 50, a2 = 0, b2 = -82.7485
#' )
#'
#' # Compare several samples with one reference color
#' delta_e_2000(
#'   l1 = 45, a1 = 18, b1 = 12,
#'   l2 = c(45, 43, 40),
#'   a2 = c(18, 16, 14),
#'   b2 = c(12, 11, 9)
#' )
#'
#' @export
delta_e_2000 <- function(
  l1,
  a1,
  b1,
  l2,
  a2,
  b2,
  k_l = 1,
  k_c = 1,
  k_h = 1
) {
  channels <- list(l1 = l1, a1 = a1, b1 = b1, l2 = l2, a2 = a2, b2 = b2)
  numeric_channels <- vapply(channels, is.numeric, logical(1))
  if (!all(numeric_channels)) {
    stop("All CIELAB coordinates must be numeric vectors.", call. = FALSE)
  }

  lengths <- lengths(channels)
  if (any(lengths == 0L)) {
    stop("CIELAB coordinate vectors must not be empty.", call. = FALSE)
  }

  output_length <- max(lengths)
  if (any(lengths != 1L & lengths != output_length)) {
    stop(
      "CIELAB coordinate vectors must have equal lengths or be length one.",
      call. = FALSE
    )
  }

  invalid_finite <- vapply(
    channels,
    function(x) any(!is.finite(x) & !is.na(x)),
    logical(1)
  )
  if (any(invalid_finite)) {
    stop("CIELAB coordinates must be finite or missing.", call. = FALSE)
  }

  weights <- list(k_l = k_l, k_c = k_c, k_h = k_h)
  valid_weights <- vapply(
    weights,
    function(x) {
      is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) && x > 0
    },
    logical(1)
  )
  if (!all(valid_weights)) {
    stop("`k_l`, `k_c`, and `k_h` must be positive finite numbers.", call. = FALSE)
  }

  channels <- lapply(channels, rep_len, length.out = output_length)
  l1 <- channels$l1
  a1 <- channels$a1
  b1 <- channels$b1
  l2 <- channels$l2
  a2 <- channels$a2
  b2 <- channels$b2

  c1 <- sqrt(a1^2 + b1^2)
  c2 <- sqrt(a2^2 + b2^2)
  c_bar <- (c1 + c2) / 2

  g <- 0.5 * (1 - sqrt(c_bar^7 / (c_bar^7 + 25^7)))
  a1_prime <- (1 + g) * a1
  a2_prime <- (1 + g) * a2
  c1_prime <- sqrt(a1_prime^2 + b1^2)
  c2_prime <- sqrt(a2_prime^2 + b2^2)
  chroma_product <- c1_prime * c2_prime

  h1_prime <- atan2(b1, a1_prime)
  h2_prime <- atan2(b2, a2_prime)
  h1_prime[h1_prime < 0] <- h1_prime[h1_prime < 0] + 2 * pi
  h2_prime[h2_prime < 0] <- h2_prime[h2_prime < 0] + 2 * pi
  h1_prime[c1_prime == 0] <- 0
  h2_prime[c2_prime == 0] <- 0

  delta_l_prime <- l2 - l1
  delta_c_prime <- c2_prime - c1_prime

  delta_h_angle <- h2_prime - h1_prime
  delta_h_angle[delta_h_angle > pi] <- delta_h_angle[delta_h_angle > pi] - 2 * pi
  delta_h_angle[delta_h_angle < -pi] <- delta_h_angle[delta_h_angle < -pi] + 2 * pi
  delta_h_angle[chroma_product == 0] <- 0
  delta_h_prime <- 2 * sqrt(chroma_product) * sin(delta_h_angle / 2)

  l_bar_prime <- (l1 + l2) / 2
  c_bar_prime <- (c1_prime + c2_prime) / 2

  h_bar_prime <- (h1_prime + h2_prime) / 2
  wrap_hue <- abs(h1_prime - h2_prime) > pi
  h_bar_prime[wrap_hue] <- h_bar_prime[wrap_hue] - pi
  h_bar_prime[h_bar_prime < 0] <- h_bar_prime[h_bar_prime < 0] + 2 * pi
  h_bar_prime[chroma_product == 0] <-
    h1_prime[chroma_product == 0] + h2_prime[chroma_product == 0]

  l_minus_50_squared <- (l_bar_prime - 50)^2
  s_l <- 1 + 0.015 * l_minus_50_squared / sqrt(20 + l_minus_50_squared)
  s_c <- 1 + 0.045 * c_bar_prime
  t <- 1 -
    0.17 * cos(h_bar_prime - pi / 6) +
    0.24 * cos(2 * h_bar_prime) +
    0.32 * cos(3 * h_bar_prime + pi / 30) -
    0.20 * cos(4 * h_bar_prime - 63 * pi / 180)
  s_h <- 1 + 0.015 * c_bar_prime * t

  delta_theta <- (30 * pi / 180) * exp(
    -((180 / pi * h_bar_prime - 275) / 25)^2
  )
  r_c <- 2 * sqrt(c_bar_prime^7 / (c_bar_prime^7 + 25^7))
  r_t <- -sin(2 * delta_theta) * r_c

  lightness_term <- delta_l_prime / (k_l * s_l)
  chroma_term <- delta_c_prime / (k_c * s_c)
  hue_term <- delta_h_prime / (k_h * s_h)

  squared_difference <-
    lightness_term^2 + chroma_term^2 + hue_term^2 +
    r_t * chroma_term * hue_term

  sqrt(pmax(squared_difference, 0))
}
