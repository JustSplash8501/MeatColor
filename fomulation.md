# CIE LAB to RGB Hexcode Conversion

## Overview

This document describes the process of converting colors from the CIE LAB color space to RGB hexadecimal codes. The conversion involves two intermediate steps: LAB → XYZ → RGB → Hex.

## Step 1: Convert CIE LAB to XYZ

The CIE LAB color space uses three components:

-   $L^*$ (Lightness): 0 to 100
-   $a^*$ (green to red): typically -128 to +127
-   $b^*$ (blue to yellow): typically -128 to +127

### Conversion Formulas

First, calculate the intermediate f values:

$$f_y = \frac{L^* + 16}{116}$$

$$f_x = \frac{a^*}{500} + f_y$$

$$f_z = f_y - \frac{b^*}{200}$$

Then calculate the relative XYZ values using the inverse transformation:

$$x_r = \begin{cases}
{f_x}^3 & \text{if } {f_x}^3 > \epsilon \\
\frac{116 f_x - 16}{\kappa} & \text{otherwise}
\end{cases}$$

$$y_r = \begin{cases}
{\left(\frac{L^* + 16}{116}\right)}^3 & \text{if } L^* > \kappa \epsilon \\
\frac{L^*}{\kappa} & \text{otherwise}
\end{cases}$$

$$z_r = \begin{cases}
{f_z}^3 & \text{if } {f_z}^3 > \epsilon \\
\frac{116 f_z - 16}{\kappa} & \text{otherwise}
\end{cases}$$

Where the constants are defined as:

$$\epsilon = \begin{cases}
0.008856 & \text{Actual CIE standard} \\
\frac{216}{24389} & \text{Intent of the CIE standard}
\end{cases}$$

$$\kappa = \begin{cases}
903.3 & \text{Actual CIE standard} \\
\frac{24389}{27} & \text{Intent of the CIE standard}
\end{cases}$$

For most applications, use the "intent" values: $\epsilon = \frac{216}{24389} \approx 0.008856$ and $\kappa = \frac{24389}{27} \approx 903.3$

Finally, scale by the reference white point (D65 illuminant):

$$X = x_r \times X_r$$

$$Y = y_r \times Y_r$$

$$Z = z_r \times Z_r$$

Reference white D65 (scaled to Y = 100): - $X_r = 95.047$ - $Y_r = 100.000$ - $Z_r = 108.883$

Note: The output XYZ values are in the nominal range \[0.0, 100.0\] when using these reference white values.

## Step 2: Convert XYZ to RGB

The XYZ values must first be scaled to the range \[0, 1\]:

$$X' = \frac{X}{100}, \quad Y' = \frac{Y}{100}, \quad Z' = \frac{Z}{100}$$

### Transformation Matrix (sRGB)

Apply the transformation matrix for sRGB color space:

$\begin{bmatrix}
r \\
g \\
b
\end{bmatrix} = \begin{bmatrix}
+3.2404542 & -1.5371385 & -0.4985314 \\
-0.9692660 & +1.8760108 & +0.0415560 \\
+0.0556434 & -0.2040259 & +1.0572252
\end{bmatrix} \begin{bmatrix}
X' \\
Y' \\
Z'
\end{bmatrix}$

Or equivalently:

$r = 3.2404542 \times X' - 1.5371385 \times Y' - 0.4985314 \times Z'$

$g = -0.9692660 \times X' + 1.8760108 \times Y' + 0.0415560 \times Z'$

$b = 0.0556434 \times X' - 0.2040259 \times Y' + 1.0572252 \times Z'$

Note: These are linear (lowercase) RGB values. The matrix **M** converts XYZ tristimulus values to linear RGB values before gamma correction is applied. Both XYZ and RGB values must use the same reference white (D65 for sRGB).

### Gamma Correction (Companding)

Apply the sRGB companding function to convert from linear to companded RGB:

For each linear component $v$ in $\{r, g, b\}$, calculate the companded component $V$ in $\{R, G, B\}$:

$$V = \begin{cases}
12.92 \times v & \text{if } v \leq 0.0031308 \\
1.055 \times v^{1/2.4} - 0.055 & \text{otherwise}
\end{cases}$$

### Clipping and Scaling

Clip values to \[0, 1\] and scale to \[0, 255\]:

$$R = \left\lfloor \max(0, \min(1, R)) \times 255 \right\rceil$$

$$G = \left\lfloor \max(0, \min(1, G)) \times 255 \right\rceil$$

$$B = \left\lfloor \max(0, \min(1, B)) \times 255 \right\rceil$$

Where $\lfloor \cdot \rceil$ denotes rounding to the nearest integer.

## Step 3: Convert RGB to Hexcode

Convert each 8-bit RGB component to hexadecimal and concatenate:

$$\text{hex} = \text{#} + \text{hex}(R) + \text{hex}(G) + \text{hex}(B)$$

Each component should be represented as a 2-digit hexadecimal value (00-FF).

## Example Conversion

Let's convert $\text{LAB}(50, 25, -25)$ to hex:

### Step 1: LAB to XYZ

Calculate the f values:

$$f_y = \frac{50 + 16}{116} = 0.5690$$

$$f_x = \frac{25}{500} + 0.5690 = 0.6190$$

$$f_z = 0.5690 - \frac{-25}{200} = 0.6940$$

Check conditions (using $\epsilon = 0.008856$, $\kappa = 903.3$):

For $x_r$: ${f_x}^3 = (0.6190)^3 = 0.2369 > 0.008856$, so $x_r = 0.2369$

For $y_r$: $L^* = 50 > \kappa \epsilon = 8.0$, so $y_r = {(0.5690)}^3 = 0.1841$

For $z_r$: ${f_z}^3 = (0.6940)^3 = 0.3341 > 0.008856$, so $z_r = 0.3341$

Scale by reference white:

$$X = 0.2369 \times 95.047 = 22.51$$

$$Y = 0.1841 \times 100.000 = 18.41$$

$$Z = 0.3341 \times 108.883 = 36.38$$

### Step 2: XYZ to RGB

Scale to \[0, 1\]:

$$X' = 0.2251, \quad Y' = 0.1841, \quad Z' = 0.3638$$

Linear RGB:

$r = 3.2404542 \times 0.2251 - 1.5371385 \times 0.1841 - 0.4985314 \times 0.3638 = 0.2650$

$g = -0.9692660 \times 0.2251 + 1.8760108 \times 0.1841 + 0.0415560 \times 0.3638 = 0.1421$

$b = 0.0556434 \times 0.2251 - 0.2040259 \times 0.1841 + 1.0572252 \times 0.3638 = 0.3850$

Apply gamma correction (all values $> 0.0031308$):

$$R = 1.055 \times (0.2650)^{1/2.4} - 0.055 = 0.5562$$

$$G = 1.055 \times (0.1421)^{1/2.4} - 0.055 = 0.4115$$

$$B = 1.055 \times (0.3850)^{1/2.4} - 0.055 = 0.6549$$

Scale to \[0, 255\]:

$$R = 142, \quad G = 105, \quad B = 167$$

### Step 3: RGB to Hex

$$\text{hex} = \text{#8E69A7}$$

![](color.png){width="904" height="164"}

## Notes

-   Colors outside the sRGB gamut will be clipped, which may result in loss of color accuracy
-   The D65 illuminant is the standard for sRGB; other illuminants will produce different results
-   If your XYZ values use a different reference white, you must apply chromatic adaptation before converting to RGB
-   Rounding errors may accumulate through the conversion process
-   For more accurate conversions, maintain higher precision throughout intermediate calculations

## References

-   CIE 1976 $L^*a^*b^*$ Color Space
-   IEC 61966-2-1:1999 (sRGB standard)
-   Bruce Lindbloom's Color Conversion Mathematics (http://www.brucelindbloom.com)