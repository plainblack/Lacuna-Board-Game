use strict;
use Image::Magick;
use File::Path qw(make_path remove_tree);
use 5.010;
use Config::JSON;

## settings
my $out_path = '/tmp/game/';
my $assets = '/data/Lacuna-Assets/';
my $config = Config::JSON->new('game.conf');

## main
init();
generate_planet_cards();

## subs
sub init {
    remove_tree $out_path;
    make_path $out_path;
}

sub generate_planet_cards {
    foreach my $card (@{$config->get('production')}) {
        say $card->{name};
        generate_planet_card($card);
    }
}

sub generate_planet_card {
    my ($attributes) = @_;
    my $card = Image::Magick->new(size=>'600x825');
    say $card->ReadImage('canvas:white');
    my $surface = Image::Magick->new;
    say $surface->ReadImage($assets.'/planet_side/surface-p15.jpg');
    say $surface->Rotate(90);
    say $surface->Resize('600x825!');
    say $card->Composite(compose => 'over', image => $surface, x => 0, y => 0);
    #say $card->Draw(stroke=>'red', fill => 'none', strokewidth=>1, primitive=>'rectangle', points=>'38,38 562,787');
    say $card->Annotate(text => $attributes->{name}, font => 'ALIEN5.ttf', y => -275, fill => 'white', pointsize => 70, gravity => 'Center');
    my $image = Image::Magick->new;
    say $image->ReadImage($assets.'/planet_side/400/'.$attributes->{image});
    say $card->Composite(compose => 'over', image => $image, x => 100, y => 165);
    $card->Set(font => 'promethean.ttf', pointsize => 35);
    say $card->Annotate(text => wrap($attributes->{description}, $card, 400), x => 100, y => 600, font => 'promethean.ttf', fill => 'white', pointsize => 35);
    say $card->Draw(stroke=>'black', fill => $attributes->{left} == 2 ? 'blue' : 'black', strokewidth=>1, primitive=>'polygon', points=>'65,400 65,450 40,425') if $attributes->{left};
    say $card->Draw(stroke=>'black', fill => $attributes->{right} == 2 ? 'blue' : 'black', strokewidth=>1, primitive=>'polygon', points=>'535,400 535,450 560,425') if $attributes->{right};
    say $card->Draw(stroke=>'black', fill => $attributes->{top} == 2 ? 'blue' : 'black', strokewidth=>1, primitive=>'polygon', points=>'275,65 325,65 300,40') if $attributes->{top};
    say $card->Draw(stroke=>'black', fill => $attributes->{bottom} == 2 ? 'blue' : 'black', strokewidth=>1, primitive=>'polygon', points=>'275,760 325,760 300,785') if $attributes->{bottom};
    $card->Write($out_path.$attributes->{name}.'.png');
}

# This function will wrap at a space or hyphen, and if a word is longer than a
# line it will just break it at the end of the first line. To figure out the
# height of the text, pass the returned string to QueryMultilineFontMetrics.
#
# pass in the string to wrap, the IM object with font and size set, and the
# width you want to wrap to; returns new string
#
# From: Gabe Schaffer,  IM Forum: f=7&t=3708       7 October 2004
#
sub wrap {
   my ($text, $img, $maxwidth) = @_;

   # figure out the width of every character in the string
   #
   my %widths = map(($_ => ($img->QueryFontMetrics(text=>$_))[4]),
      keys %{{map(($_ => 1), split //, $text)}});

   my (@newtext, $pos);
   for (split //, $text) {
      # check to see if we're about to go out of bounds
      if ($widths{$_} + $pos > $maxwidth) {
         $pos = 0;
         my @word;
         # if we aren't already at the end of the word,
         # loop until we hit the beginning
         if ( $newtext[-1] ne " "
              && $newtext[-1] ne "-"
              && $newtext[-1] ne "\n") {
            unshift @word, pop @newtext
               while ( @newtext && $newtext[-1] ne " "
                       && $newtext[-1] ne "-"
                       && $newtext[-1] ne "\n")
         }

         # if we hit the beginning of a line,
         # we need to split a word in the middle
         if ($newtext[-1] eq "\n" || @newtext == 0) {
            push @newtext, @word, "\n";
         } else {
            push @newtext, "\n", @word;
            $pos += $widths{$_} for (@word);
         }
      }
      push @newtext, $_;
      $pos += $widths{$_};
      $pos = 0 if $newtext[-1] eq "\n";
   }

   return join "", @newtext;
}
