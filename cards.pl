use strict;
use Image::Magick;
use File::Path qw(make_path remove_tree);
use 5.010;
use Config::JSON;
use utf8;

## settings
my $assets = '/data/Lacuna-Assets/';
my $config = Config::JSON->new('game.conf');

## main
init();
generate_decks();

## subs
sub init {
    remove_tree $config->get('out_path');
    make_path $config->get('out_path');
}

sub generate_decks {
    foreach my $deck (@{$config->get('decks')}) {
        next unless $deck->{enabled};
        generate_deck($deck);
    }
}

sub generate_deck {
    my $deck = shift;
    my $out_path = $config->get('out_path').'/'.$deck->{name};
    say $out_path;
    generate_deck_back($out_path, $deck);
    make_path $out_path;
    foreach my $card (@{$deck->{cards}}) {
        say $card->{name};
        generate_card($out_path, $deck, $card);
    }
}

sub generate_deck_back {
    my ($out_path, $deck) = @_;
    say "generating deck back";
    my $card = Image::Magick->new(size=>$deck->{size});
    say $card->ReadImage('canvas:white');
    my $surface = Image::Magick->new;
    say $surface->ReadImage($deck->{background});
    say $surface->Rotate(90);
    say $surface->Resize($deck->{size}.'!');
    say $card->Composite(compose => 'over', image => $surface, x => 0, y => 0);
    say $card->Rotate(-90);
    say $card->Annotate(text => $deck->{name}, font => 'ALIEN5.ttf', fill => 'white', pointsize => 200, gravity => 'Center');
    say $card->Rotate(90);

    # draw cut line
    if ($deck->{show_cut_line}) {
        say $card->Draw(stroke=>'red', fill => 'none', strokewidth=>1, primitive=>'rectangle', points=>'38,38 562,787');
    }
    say $card->Write($out_path.'.png');
}

sub generate_card {
    my ($out_path, $deck, $attributes) = @_;

    # create a new blank card
    my $card = Image::Magick->new(size=>$deck->{size});
    say $card->ReadImage('canvas:white');

    # add the backdround to the card
    my $surface = Image::Magick->new;
    say $surface->ReadImage($attributes->{background} || $deck->{background});
    say $surface->Rotate(90);
    say $surface->Resize($deck->{size}.'!');
    say $card->Composite(compose => 'over', image => $surface, x => 0, y => 0);

    # add the card's title
    say $card->Annotate(text => $attributes->{name}, font => 'ALIEN5.ttf', y => -275, fill => 'white', pointsize => 70, gravity => 'Center');

    # add a pip for each quanity count of the card
    my $pips = '.' x $attributes->{quantity};
    say $card->Annotate(text => $pips, y => -340, fill => 'white', pointsize => 70, gravity => 'Center');

    # add the foreground image to the card
    my $image = Image::Magick->new;
    say $image->ReadImage($attributes->{image});
    if ($attributes->{resize}) {
        say $image->Resize('400x400');
    }
    say $card->Composite(compose => 'over', image => $image, x => 100, y => 165);

    # set up for text description and icons for card abilities
    $card->Set(font => 'promethean.ttf', pointsize => 35);
    my $text_y = 610;
    my $icon_x_mod = 0;

    # card ability icons
    foreach my $icon_data (@{$attributes->{icons}}) {
        my $icon = Image::Magick->new;
        say $icon->ReadImage($icon_data->{image});
        say $card->Composite(compose => 'over', image => $icon, x => 100 + $icon_x_mod, y => 610 - 40);
        say $card->Annotate(text => $icon_data->{description}, x => 165 + $icon_x_mod, y => 610, font => 'promethean.ttf', fill => 'white', pointsize => 35);
        $text_y = 610 + 60;
        $icon_x_mod += 140;    
    }

    # card ability text
    say $card->Annotate(text => wrap($attributes->{description}, $card, 400), x => 100, y => $text_y, font => 'promethean.ttf', fill => 'white', pointsize => 35);

    # connection points
    draw_connection_point($card, $attributes->{left}, 90, 0, 390); 
    draw_connection_point($card, $attributes->{right}, 270, 515, 390); 
    draw_connection_point($card, $attributes->{top}, 180, 265, 0); 
    draw_connection_point($card, $attributes->{bottom}, 0, 265, 740); 

    # display cut line
    if ($deck->{show_cut_line}) {
        say $card->Draw(stroke=>'red', fill => 'none', strokewidth=>1, primitive=>'rectangle', points=>'38,38 562,787');
    }

    # save the card to disk
    say $card->Write($out_path.'/'.$attributes->{name}.'.png');
}

sub draw_connection_point {
    my ($card, $color, $rotation, $x, $y) = @_;
    if ($color) {
        # draw a half circle
        my $half_circle  = Image::Magick->new(size=>'70x35');
        say $half_circle->ReadImage('canvas:transparent');
        say $half_circle->Draw(stroke => $color, fill => $color, strokewidth=>1, primitive=>'circle', points=>'35,35, 35,70');

        # create the connection point image
        my $connection = Image::Magick->new(size=>'70x85');
        say $connection->ReadImage('canvas:transparent');

        # add the half circle to the connection point
        say $connection->Composite(compose => 'over', image => $half_circle, x => 0, y => 0);

        # extend the connection point the the edge
        say $connection->Draw(stroke=>$color, fill => $color, strokewidth=>1, primitive=>'rectangle', points=>'0,35 70,85');

        # orient the connection point for its position 
        say $connection->Rotate($rotation);

        # apply the connection point to the image
        say $card->Composite(compose => 'over', image => $connection, x => $x, y => $y);
    }
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
