#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;

my %options = (
	debug => 0,
	csvfile => undef
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
	create_latex(%logic_expressions);
}

sub create_latex {
	my %logic_expressions = @_;

	my @latex = ();
	foreach my $output_name (sort { $a cmp $b || $a <=> $b } keys %logic_expressions) {
		my $latex_code = "$output_name = ";
		my @dataset = @{$logic_expressions{$output_name}};
		my @latex_dataset = ();
		foreach my $this_dataset (@dataset) {
			push @latex_dataset, "(".join(" \\wedge ", map { $_->{negated} ? " \\lnot ".$_->{value} : $_->{value} } @$this_dataset).")";
		}
		
		$latex_code .= join(" \\lor ", @latex_dataset);

		$latex_code =~ s#!# \\lnot #g;
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
					push @{$logic_expressions{$output_name}}, \@logic;
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

analyze_args(@ARGV);
main();
