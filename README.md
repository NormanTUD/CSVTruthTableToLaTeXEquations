# Idea

Turn a list values in a CSV-file that corresponds to a truth table with multiple in- and outputs
into a nice LaTeX-list of equations for getting this exact output.

![Screenshot](example.jpg?raw=true "Example")

# Example

```console
perl truth_table_to_dnf.pl --debug --csvfile=test.csv > latex.tex
```

Use the `--simplify` option for checking for entries that are always true/always false. These will
then be prepended to the equation in such a way that the equations are simpler and faster to calculate.

```console
perl truth_table_to_dnf.pl --debug --simplify --csvfile=test.csv > latex_simplify.tex
```
