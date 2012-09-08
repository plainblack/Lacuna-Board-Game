use strict;
use 5.010;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use URI;
use Data::Printer;
use DateTime;
use Config::JSON;

my $config = Config::JSON->new('game.conf');

# create session
say "Creating session";
my $session = post('session',[
     username    => $ENV{TGC_USER},
     password    => $ENV{TGC_PASS},
     api_key_id  => $ENV{TGC_API_KEY},
]);

# get user
say "Fetching user";
my $user = get('user/'.$session->{user_id},[
    session_id  => $session->{id},
    include_related_objects => 1,
    include_relationships => 1,
]);

# get game
say "Fetching game details";
my $game = get('game/'.$config->get('game_id'), [
    session_id  => $session->{id},
    include_relationships => 1,
]);

# delete old decks
say "Deleting old decks";
my $decks = get($game->{_relationships}{minidecks});
foreach my $deck (@{$decks->{items}}) {
    del('minideck/'.$deck->{id}, [ 
        session_id  => $session->{id},
    ]);
}

# create folder
say "Creating game folder";
my $game_folder = post('folder',[
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
    my $folder = post('folder',[
        name        => $deck_config->{name},
        session_id  => $session->{id},
        user_id     => $user->{id},
        parent_id   => $game_folder->{id},
    ]);
    my $out_path = $config->get('out_path').'/'.$deck_config->{name};
    say "Uploading deck back";
    my $back = post('file',[
        name        => $deck_config->{name}.'.png',
        folder_id   => $folder->{id},
        file        => [$out_path .'.png'],
        session_id  => $session->{id},
    ]);
    say "Creating deck";
    my $deck = post('minideck', [
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
        my $face = post('file',[
            name        => $card_config->{name},
            folder_id   => $folder->{id},
            file        => [$out_path .'/'. $card_config->{name}.'.png'],
            session_id  => $session->{id},
        ]);
        say "Creating card";
        my $card = post('minicard', [
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
exit;

sub get {
    my ($path, $params) = @_;
    unless ($path =~ m/^\/api/) {
        $path = '/api/'.$path;
    }
    my $uri = URI->new('https://www.thegamecrafter.com'.$path);
    $uri->query_form($params);
    my $response = LWP::UserAgent->new->request( GET $uri->as_string);
    my $result = from_json($response->decoded_content); 
    if ($response->is_success) {
        say $result->{result}{object_name}.' ID: ', $result->{result}{id};
        return $result->{result};
    }
    else {
        die 'Error: ', $result->{error}{message};
    }
}

sub del {
    my ($path, $params) = @_;
    unless ($path =~ m/^\/api/) {
        $path = '/api/'.$path;
    }
    my $uri = URI->new('https://www.thegamecrafter.com'.$path);
    $uri->query_form($params);
    my $response = LWP::UserAgent->new->request( POST 'https://www.thegamecrafter.com'.$path, 'X-HTTP-Method' => 'DELETE', Content_Type => 'form-data', Content => $params );
    my $result = from_json($response->decoded_content); 
    if ($response->is_success) {
        say "Deleted successfully!";
    }
    else {
        die 'Error: ', $result->{error}{message};
    }
}

sub post {
    my ($path, $params) = @_;
    unless ($path =~ m/^\/api/) {
        $path = '/api/'.$path;
    }
    my $response = LWP::UserAgent->new->request( POST 'https://www.thegamecrafter.com'.$path, Content_Type => 'form-data', Content => $params );
    my $result = from_json($response->decoded_content); 
    if ($response->is_success) {
        say $result->{result}{object_name}.' ID: ', $result->{result}{id};
        sleep 3; # so as not to overuse my RPCs
        return $result->{result};
    }
    else {
        die 'Error: '. $response->status_line. ' '. $result->{error}{message};
    }
}

