# Regression to the Marshmallow Girls

This repo contains data and code for the marshmallow experiment (no, not that one) as presented on episode 7 of _Regression to the Mean Girls_.

<!-- Link / embed -->

I set out to answer the question:

> Do white and pink marshmallows have a different flavor?

## Methods

### Participants

24 unassuming undergrad students in [the Statistics and Data Analysis program at Ben-Gurion University](https://www.bgu.ac.il/u/faculties/interdisciplinary/schools/statistics-data-analysis/)
and graduate students from [the Psychology Department at Ben-Gurion University](https://www.bgu.ac.il/en/u/faculties/humanities-and-social-sciences/departments/psychology/) and [the Psychology School at Tel Aviv University](https://en-social-sciences.tau.ac.il/psy)
volunteered to eat some marshmallows.
(Two additional data points were collected from me and my wife, Naama.)

The experiment had two parts: the triangle test and the identification test - 
a modren take on [the lady tasting tea experiment](https://en.wikipedia.org/wiki/Lady_tasting_tea).

### Design

In the triangle test, 3 marshmallows were placed in front of blindfolded participants:
two were of the same color, and one was of a different color, with the order and colors randomly determined.
Students were instructed to try and guess which was the odd-one-out. They were free to eat, taste, nibble, smell and do whatever they wanted.

After completing the triangle test, they were handed a fourth marshmallow (still blindfolded) for the identification test. The color of the marshmallow was also randomly determined.

### Statistical Analysis

For the triangle test, a simple logistic regression analysis was used to predict the probability of correctly identifying the odd-one-out.
If there is a noticeable difference, we would expect this probability to be higher than chance - 1/3.
The color of the odd-one-out was also included to explore the possibility that it is easier/harder to detect an odd _pink_ marshmallow than an odd _white_ marshmallow.

For the identification test, an additional binomial model with a probit link was used,
predicting participants responses from the actual color of the marshmallow.
[It can be shown](https://doi.org/10.1037/1082-989X.3.2.186) that such a model can be used to estimate the _Signal Detection Theory_ parameters, with the slope for the indicator variable being equal to $d'$ and the intercept ($\times -1$) being equal to the criterion $c$.

See [the code file](script.R) for the actual analysis.

## Results

### The Triangle Test

![](/outputs/fig-triangle.png)

### Signal Detection Theory (SDT)

![](/outputs/fig-sdt.png)

---

## Addendum

_May 21st 2026 update:_ I recived an official response from a food scientist on behalf of the marshmallow company:

> There of no differences in the ingredients except for the color and the pink marshmallow contains strawberry extract.
