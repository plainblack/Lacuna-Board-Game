use strict;
use 5.010;
use TheGameCrafter::Client;
use DateTime;
use Config::JSON;
use Getopt::Long;

# settings
my $config_file;
GetOptions(
    'config=s' => \$config_file,
);
unless ($config_file) {
    say "Usage: $0 --config=game.conf";
    exit;
}
my $config = Config::JSON->new($config_file);


# create session
say "Creating session";
my $session = tgc_post('session',[
     username    => $ENV{TGC_USER},
     password    => $ENV{TGC_PASS},
     api_key_id  => $ENV{TGC_API_KEY},
]);

# get user
say "Fetching user";
my $user = tgc_get('user/'.$session->{user_id},[
    session_id  => $session->{id},
    include_related_objects => 1,
    include_relationships => 1,
]);

# get game
say "Fetching game details";
my $game = tgc_get('game/'.$config->get('game_id'), [
    session_id  => $session->{id},
    include_relationships => 1,
]);

# delete old decks
say "Deleting old decks";
my $decks = tgc_get($game->{_relationships}{minidecks});
foreach my $deck (@{$decks->{items}}) {
    tgc_delete('minideck/'.$deck->{id}, [ 
        session_id  => $session->{id},
    ]);
}

# create folder
say "Creating game folder";
my $game_folder = tgc_post('folder',[
    name        => 'Lacuna Expanse',
    session_id  => $session->{id},
    user_id     => $user->{id},
    parent_id   => $user->{root_folder}{id},
]);

# create decks
say "Creating new decks";
foreach my $deck_config (@{$config->get('decks')}) {
    say $deck_config->{name};
    say "Creating folder";
    my $folder = tgc_post('folder',[
        name        => $deck_config->{name},
        session_id  => $session->{id},
        user_id     => $user->{id},
        parent_id   => $game_folder->{id},
    ]);
    my $out_path = $config->get('out_path').'/'.$deck_config->{name};
    say "Uploading deck back";
    my $back = tgc_post('file',[
        name        => $deck_config->{name}.'.png',
        folder_id   => $folder->{id},
        file        => [$out_path .'.png'],
        session_id  => $session->{id},
    ]);
    say "Creating deck";
    my $deck = tgc_post('minideck', [
        name                => $deck_config->{name},
        game_id             => $game->{id},
        session_id          => $session->{id},
        back_id             => $back->{id},
        has_proofed_back    => 1,
    ]);
    say "Creating cards";
    foreach my $card_config (@{$deck_config->{cards}}) {
        say $card_config->{name};
        say "Uploading face";
        my $face = tgc_post('file',[
            name        => $card_config->{name},
            folder_id   => $folder->{id},
            file        => [$out_path .'/'. $card_config->{name}.'.png'],
            session_id  => $session->{id},
        ]);
        say "Creating card";
        my $card = tgc_post('minicard', [
            name                => $card_config->{name},
            quantity            => $card_config->{quantity},
            deck_id             => $deck->{id},
            session_id          => $session->{id},
            face_id             => $face->{id},
            has_proofed_face    => 1,
        ]);
    }
}

say "All done!";

