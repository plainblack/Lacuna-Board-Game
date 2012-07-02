use strict;
use 5.010;
use Config::JSON;

opendir my $folder, '/data/Lacuna-Assets/planet_side';
my @files = readdir $folder;
closedir $folder;

my $config = Config::JSON->new('game.conf');
$config->set('production',[]);
foreach my $file (@files) {
    next unless $file =~ m/^(.*)9.png$/;
    my $name = ucfirst $1;
    say $name;
    $config->addToArray('production', {
            image       => $file, 
            name        => $name, 
            description => '', 
            quantity    => 1,
            left        => 1,
            right       => 1,
            top         => 1,
            bottom      => 1,
    });
}
