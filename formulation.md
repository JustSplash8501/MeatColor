# CIELAB to sRGB Hex Conversion

## Scope and assumptions

`MeatColor::summarize_lab()` converts mean CIELAB coordinates with:

```r
colorspace::hex(colorspace::LAB(L, a, b))
```

The conversion path is CIELAB → CIEXYZ → linear-light sRGB → encoded
sRGB → hexadecimal.

This calculation assumes:

- the input is **CIE 1976 L\*a\*b\*** (CIELAB), not Hunter Lab;
- the CIELAB values use the same D65/2° reference white as the `colorspace`
  package default; and
- the intended output is the sRGB display color space.

Colorimeter exports can depend on illuminant, observer angle, and color-space
settings. Confirm that the instrument exported CIELAB values under D65 with
the 2° standard observer before interpreting the generated hex values as
sRGB. Values measured relative to another white point or observer require an
appropriate conversion before the sRGB matrix is applied.

## Step 1: Convert CIELAB to CIEXYZ

For CIELAB coordinates \(L^*\), \(a^*\), and \(b^*\), define:

$$
f_y = \frac{L^* + 16}{116}, \qquad
f_x = f_y + \frac{a^*}{500}, \qquad
f_z = f_y - \frac{b^*}{200}
$$

Use the exact CIELAB constants:

$$
\epsilon = \frac{216}{24389} \approx 0.008856451679
$$

$$
\kappa = \frac{24389}{27} \approx 903.2962963
$$

The inverse CIELAB transfer function is:

$$
f^{-1}(t) =
\begin{cases}
t^3 & \text{if } t^3 > \epsilon \\
\dfrac{116t - 16}{\kappa} & \text{otherwise}
\end{cases}
$$

The relative tristimulus values are:

$$
x_r = f^{-1}(f_x), \qquad
y_r =
\begin{cases}
f_y^3 & \text{if } L^* > 8 \\
\dfrac{L^*}{\kappa} & \text{otherwise}
\end{cases},
\qquad
z_r = f^{-1}(f_z)
$$

The boundary \(L^*=8\) follows from \(\kappa\epsilon=8\).

For the D65 reference white used by `colorspace`, scaled so \(Y_n=100\):

$$
(X_n, Y_n, Z_n) = (95.047,\ 100.000,\ 108.883)
$$

Then:

$$
X = X_n x_r, \qquad Y = Y_n y_r, \qquad Z = Z_n z_r
$$

XYZ components are not each restricted to \([0,100]\). In particular, the
D65 reference-white value \(Z_n\) is greater than 100, and colors outside the
sRGB gamut can produce values outside the usual display range.

## Step 2: Convert CIEXYZ to linear-light sRGB

The `colorspace` implementation uses XYZ values scaled to \(Y_n=100\) and the
following D65 matrix:

$$
\begin{bmatrix}
r \\
g \\
b
\end{bmatrix}
=
\begin{bmatrix}
 3.240479 & -1.537150 & -0.498535 \\
-0.969256 &  1.875992 &  0.041556 \\
 0.055648 & -0.204043 &  1.057311
\end{bmatrix}
\begin{bmatrix}
X/100 \\
Y/100 \\
Z/100
\end{bmatrix}
$$

Here \(r\), \(g\), and \(b\) are linear-light components, not yet encoded
sRGB values.

## Step 3: Apply the sRGB transfer function

For each linear-light component \(v\), the IEC sRGB encoding function is:

$$
V =
\begin{cases}
12.92v & \text{if } v \le 0.0031308 \\
1.055v^{1/2.4} - 0.055 & \text{if } v > 0.0031308
\end{cases}
$$

The current `colorspace` C implementation uses `0.00304` as its branch
threshold. This small implementation difference does not affect the worked
example below, but the formula above gives the standard sRGB threshold.

## Step 4: Quantize and encode as hexadecimal

For an in-gamut encoded component \(V\):

$$
C_8 = \operatorname{round}(255V)
$$

Each resulting integer is written as a two-digit hexadecimal value and
concatenated:

$$
\text{hex} = \texttt{\#RRGGBB}
$$

`MeatColor` currently calls `colorspace::hex()` with its default
`fixup = FALSE`. Therefore, if any rounded component lies outside 0–255,
`colorspace` returns `NA` rather than clipping the color. Calling
`colorspace::hex(..., fixup = TRUE)` would instead clamp out-of-range
components to the nearest endpoint.

## Verified example: CIELAB(50, 25, -25)

First:

$$
f_y = 0.5689655172,\qquad
f_x = 0.6189655172,\qquad
f_z = 0.6939655172
$$

All three values use the cubic branch:

$$
x_r = 0.2371370239,\qquad
y_r = 0.1841865185,\qquad
z_r = 0.3342055621
$$

Scaling by the D65 reference white gives:

$$
X = 22.53916271,\qquad
Y = 18.41865185,\qquad
Z = 36.38930421
$$

Using the matrix implemented by `colorspace` gives linear-light sRGB:

$$
r = 0.2658411096,\qquad
g = 0.1421921876,\qquad
b = 0.3597087397
$$

After sRGB encoding:

$$
R = 0.5524516066,\qquad
G = 0.4130411268,\qquad
B = 0.6340203340
$$

Quantizing to 8-bit components gives:

$$
(R_8,G_8,B_8) = (141,105,162)
$$

Therefore:

$$
\boxed{\texttt{\#8D69A2}}
$$

This result matches:

```r
colorspace::hex(colorspace::LAB(50, 25, -25))
#> "#8D69A2"
```

## Interpretation limits

- A screen swatch is an sRGB approximation of measured color, not a
  color-managed reproduction of the physical meat sample.
- CIELAB coordinates are meaningful only with their reference illuminant,
  observer, and measurement geometry.
- Out-of-gamut CIELAB colors cannot be represented exactly in sRGB.
- Keep full precision through the intermediate calculations and round only
  when producing the final 8-bit channels.

## References

- [CIE 15:2018, *Colorimetry, 4th Edition*](https://cie.co.at/publications/colorimetry-4th-edition)
- [ICC sRGB registry entry (IEC 61966-2-1)](https://registry.color.org/rgb-registry/srgb)
- [CRAN `colorspace` reference manual](https://cran.r-project.org/web/packages/colorspace/refman/colorspace.html)
- [`colorspace` conversion source](https://github.com/cran/colorspace/blob/master/src/colorspace.c)
