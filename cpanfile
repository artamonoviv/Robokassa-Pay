requires "Digest::MD5"      => "2.55";
requires "Digest::SHA"    => "6.01";
requires "URI::Escape"      => "3.31";

on 'test' => sub {
    requires 'Test::More', '0.98';
};

