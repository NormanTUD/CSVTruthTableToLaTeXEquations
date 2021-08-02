#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

my %options = (
	debug => 0,
	csvfile => undef,
	simplify => 0
);

sub debug (@) {
	if($options{debug}) {
		foreach (@_) {
			warn "$_\n";
		}
	}
}

sub analyze_args {
	foreach (@_) {
		if(/^--debug$/) {
			$options{debug} = 1;
		} elsif(/^--csvfile=(.*)$/) {
			$options{csvfile} = $1;
		} elsif(/^--simplify$/) {
			$options{simplify} = 1;
		} else {
			die "Unknown parameter $_";
		}
	}

	die "--csvfile=FILENAME.csv not defined" unless defined $options{csvfile};
	die "$options{csvfile} does not exist" unless -e $options{csvfile};
}

sub main {
	my @data = get_data();
	my %logic_expressions = get_logic_expressions(@data);
	if($options{simplify}) {
		%logic_expressions = simplify_logic_expression(%logic_expressions);
	}
	create_latex(%logic_expressions);
}

sub simplify_logic_expression {
	my %logic_expressions = @_;

	my %simplified_logic_expression = ();

	my %always_true_always_false = ();

	for my $output_name (sort { $a cmp $b || $a <=> $b } keys %logic_expressions) {
		my @always_true = ();
		my @always_false = ();

		my %negated_list = ();

		foreach my $equation_set (@{$logic_expressions{$output_name}{equations}}) {
			foreach my $item (@{$equation_set}) {
				push @{$negated_list{$item->{value}}}, $item->{negated};
			}
		}

		foreach my $key (keys %negated_list) {
			my @array = @{$negated_list{$key}};
			if(array_contains_only(0, @array)) { # all not negated
				push @always_true, $key;
			} elsif (array_contains_only(1, @array)) { # all negated
				push @always_false, $key;
			}
		}
		push @{$always_true_always_false{$output_name}{always_true}}, @always_true;
		push @{$always_true_always_false{$output_name}{always_false}}, @always_false;
	}

	for my $output_name (sort { $a cmp $b || $a <=> $b } keys %logic_expressions) {
		my @always_true = @{$always_true_always_false{$output_name}{always_true}};
		my @always_false = @{$always_true_always_false{$output_name}{always_false}};

		foreach my $this_always_true (@always_true) {
			push @{$simplified_logic_expression{$output_name}{always_true}}, { value => $this_always_true, negated => 0 };
		}

		foreach my $this_always_false (@always_false) {
			push @{$simplified_logic_expression{$output_name}{always_false}}, { value => $this_always_false, negated => 1 };
		}

		my $j = 0;
		foreach my $equation_set (@{$logic_expressions{$output_name}{equations}}) {
			foreach my $equation (@{$equation_set}) {
				if(!grep { $equation->{value} eq $_ } @always_true) {
					if(!grep { $equation->{value} eq $_ } @always_false) {
						push @{$simplified_logic_expression{$output_name}{equations}[$j]}, $equation;
					}
				}
			}
			$j++;
		}
	}

	return %simplified_logic_expression;
}

sub create_latex {
	my %logic_expressions = @_;


	my @latex = ();
	foreach my $output_name (sort { $a cmp $b || $a <=> $b } keys %logic_expressions) {
		my $latex_code = "";
		my @dataset = @{$logic_expressions{$output_name}{equations}};

		my @always_true = ();
		if(exists $logic_expressions{$output_name}{always_true}) {
			@always_true = $logic_expressions{$output_name}{always_true};
		}

		my @always_false = ();
		if(exists $logic_expressions{$output_name}{always_false}) {
			@always_false = $logic_expressions{$output_name}{always_false};
		}

		my @latex_dataset = ();
		foreach my $this_dataset (@dataset) {
			if(@$this_dataset > 1) {
				push @latex_dataset, "(".join(" \\wedge ", map { $_->{negated} ? " \\lnot ".$_->{value} : $_->{value} } @$this_dataset).")";
			} else {
				push @latex_dataset, join(" \\wedge ", map { $_->{negated} ? " \\lnot ".$_->{value} : $_->{value} } @$this_dataset);
			}
		}
		
		$latex_code .= join(" \\lor ", @latex_dataset);

		if(@always_true) {
			if(@always_true > 1) {
				$latex_code = "(".join(" \\wedge ", map { $_->[0]->{value} } @always_true).") \\wedge ($latex_code)";
			} else {
				$latex_code = join(" \\wedge ", map { $_->[0]->{value} } @always_true)." \\wedge ($latex_code)";
			}
		}

		if(@always_false) {
			if(@always_false > 1) {
				$latex_code = "(".join(" \\wedge ", map { " \\lnot ".$_->[0]->{value} } @always_false).") \\wedge ($latex_code)";
			} else {
				$latex_code = join(" \\wedge ", map { " \\lnot ".$_->[0]->{value} } @always_false)." \\wedge ($latex_code)";
			}
		}

		$latex_code = "$output_name = $latex_code";

		push @latex, $latex_code;
	}

	my $code = "";
	foreach my $lc (@latex) {
		$code = $code."\n\$\$$lc\$\$\n";
	}

	print <<EOF;
\\documentclass{scrartcl}

\\begin{document}
	$code
\\end{document}
EOF
}

sub get_logic_expressions {
	my @data = @_;
	my %logic_expressions = ();
	foreach my $dataset (@data) {
		if (!exists $dataset->{headers}) {
			my @input = @{$dataset->{input}};
			my @output = @{$dataset->{output}};

			my $j = $#input + 1;
			foreach my $this_output (@output) {
				my $output_name = $data[0]->{headers}->[$j];
				my @logic = ();
				if($this_output) {
					my $k = 0;
					foreach my $this_input (@input) {
						my $this_input_name = $data[0]->{headers}->[$k];
						if($this_input == 1) {
							push @logic, { negated => 0, value => $this_input_name };
						} else {
							push @logic, { negated => 1, value => $this_input_name };
						}
						$k++;
					}
				}
				if(@logic) {
					push @{$logic_expressions{$output_name}{equations}}, \@logic;
				}
				$j += 1;
			}
		}
	}

	return %logic_expressions;
}

sub get_data {
	my @data = ();
	my $first = 1;
	open my $fh, '<', $options{csvfile};
	my $max_input_index = undef;
	my $i = 1;
	my $number_of_headlines = undef;

	while (my $line = <$fh>) {
		chomp $line;
		if($first == 1) {
			$number_of_headlines = scalar(split(/,/, $line)) - 1;
			if($line =~ m#^((?:x_?\d+,?)+)(?:,y_?\d+)+$#) {
				my @input = split /,/, $1;
				$max_input_index = scalar @input - 1;
				push @data, { headers => [split /,/, $line] };
			} else {
				die "First line is malformed";
			}
		} else {
			if($line =~ m#^([01],?)+$#) {
				my @values = split /,/, $line;
				if($#values != $number_of_headlines) {
					die "Not enough values in Line $i";
				}
				my @input = @values[0 .. $max_input_index];
				my @output = @values[$max_input_index + 1 .. $#values];
				push @data, { input => \@input, output => \@output };
			} else {
				die "Line $i malformed";
			}
		}
		$first = 0;
		$i++;
	}
	close $fh;

	return @data;
}

sub array_contains_only {
	my $x = shift;
	my @array = @_;

	foreach my $val (@array) {
		if($x != $val) {
			return 0;
		}
	}
	return 1;
}

analyze_args(@ARGV);
main();
