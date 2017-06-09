tidy:
	find . -name '*.p?.bak' -delete
	. /etc/profile.d/perl5.sh;find lib t -name '*.p[lm]' -o -name '*.t' | xargs perltidy -pro=/home/git/regentmarkets/cpan/rc/.perltidyrc --backup-and-modify-in-place -bext=tidyup
	find . -name '*.tidyup' -delete

doc:
	pod2markdown lib/Finance/VolSurface.pm > README.md
	for i in lib/Finance/VolSurface/*.pm; do echo; echo '---'; echo; pod2markdown $$i; done >> README.md

