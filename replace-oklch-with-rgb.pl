# SPDX-License-Identifier: Unlicense

# How to install:
#   1. prefix=$HOME/.local
#   2. install -D <(cat <(printf '#!/usr/bin/env perl\n\n') replace-oklch-with-rgb.pl) "$prefix/bin/replace-oklch-with-rgb"

use v5.38;

use Math::Trig;

sub apply_gamma {
	my ($v) = @_;
	if ($v > 0.0031308) {
		return 1.055 * $v ** (1/2.4) - 0.055;
	}
	else {
		return 12.92 * $v;
	}
}

sub linear_srgb_to_rgb {
	my ($linear_red, $linear_green, $linear_blue) = @_;
	return apply_gamma($linear_red), apply_gamma($linear_green), apply_gamma($linear_blue);
}

sub oklab_to_linear_srgb {
	my ($L, $a, $b) = @_;
	my $l = ($L + 0.3963377774 * $a + 0.2158037573 * $b) ** 3;
	my $m = ($L - 0.1055613458 * $a - 0.0638541728 * $b) ** 3;
	my $s = ($L - 0.0894841775 * $a - 1.2914855480 * $b) ** 3;
	return +4.0767416621 * $l - 3.3077115913 * $m + 0.2309699292 * $s, -1.2684380046 * $l + 2.6097574011 * $m - 0.3413193965 * $s, -0.0041960863 * $l - 0.7034186147 * $m + 1.7076147010 * $s;
}

sub oklab_to_rgb {
	my ($l, $a, $b) = @_;
	return linear_srgb_to_rgb(oklab_to_linear_srgb($l, $a, $b));
}

sub oklch_to_oklab {
	my ($l, $c, $h) = @_;
	return $l, cos(deg2rad($h)) * $c, sin(deg2rad($h)) * $c;
}

sub main {
	my $pattern = qr/oklch\(\s*(?<lightness>\d+(?:\.\d+)?)%\s+(?<chroma>\d+(?:\.\d+)?)\s+(?<hue>\d+(?:\.\d+)?)\s*\)/;

	# get input either from stdin or from files
	while (<<>>) {
		if (m/$pattern/) {
			my ($red, $green, $blue) = map { int($_ * 255 + 0.5) } oklab_to_rgb(oklch_to_oklab($+{lightness} / 100, $+{chroma}, $+{hue}));
			s/$pattern/rgb($red $green $blue)/;
		}
		print;
	}
}

main();

# vim: ts=8 sts=0 sw=8 noet
