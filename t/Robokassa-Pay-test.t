use strict;
use warnings;

use Test::More tests => 7;

use_ok('Robokassa::Pay');

my @params = qw(
    Email OutSum MerchantLogin Encoding InvDesc InvId
        UserIp IncCurrLabel Culture ExpirationDate OutSumCurrency
        IsTest Password1 Password2
        PayUrl SignatureValue
    );

subtest 'new() tests' => sub {
        plan tests => 9;

        ok(Robokassa::Pay->can('new'), 'method new() is available');

        my $robokassa = Robokassa::Pay->new();

        is(ref($robokassa), 'Robokassa::Pay', 'new() returns an instance of Robokassa::Pay');

        eval {
            $robokassa = Robokassa::Pay->new(Recurring => 1);
        };

        like($@, qr/Recurring payment is not yet supported/, 'Recurring payment denial');

        eval {
           $robokassa = Robokassa::Pay->new(OriginId => 1);
        };

        like($@, qr/The second check is not yet supported/, 'The second check denial');

        eval {
            $robokassa = Robokassa::Pay->new(Email1 => 'foo@bar.some');
        };

        like($@, qr/Unknown param: Email1/, 'Unknown param checking');

        eval {
            $robokassa = Robokassa::Pay->new(Algorithm => 'md6');
        };

        like($@, qr/Unknown hashing algorithm: md6/, 'Unknown hashing algorithm checking');

        $robokassa = Robokassa::Pay->new(
            Shp_customerName => 'Ivan',
            Shp_customerLastName => 'Smirnoff'
        );

        is($robokassa->{Shp_customerName}, 'Ivan', 'User-defined parameter 1');
        is($robokassa->{Shp_customerLastName}, 'Smirnoff', 'User-defined parameter 2');

        my %params = map { $_ => 1 } @params;

        $robokassa = Robokassa::Pay->new(%params);

        map {delete($params{$_}) if ($robokassa->{$_} == 1) } @params;

        ok(!keys %params, 'new() takes %params');

    };

subtest 'param() tests' => sub {
        plan tests => 6;

        ok(Robokassa::Pay->can('param'), 'method param() is available');

        my $robokassa = Robokassa::Pay->new();

        my %params = map { $_ => 1 } @params;

        $robokassa->param( $_ => 1 ) foreach @params;

        map {delete($params{$_}) if ($robokassa->{$_} == 1) } @params;

        ok(!keys %params, 'param() works');

        $robokassa = Robokassa::Pay->new();

        $robokassa -> param(Email => 'foo@bar.some', OutSum => 1000);

        ok(($robokassa->{Email} eq 'foo@bar.some' && $robokassa->{OutSum} == 1000), 'param() takes several parameters');

        $robokassa -> param(Shp_customerName => 'Ivan', Shp_customerLastName => 'Smirnoff');

        is($robokassa->{Shp_customerName}, 'Ivan', 'User-defined parameter 1');
        is($robokassa->{Shp_customerLastName}, 'Smirnoff', 'User-defined parameter 2');

        eval {
            $robokassa -> param(Algorithm => 'md6');
        };

        like($@, qr/Unknown hashing algorithm: md6/, 'Unknown hashing algorithm checking');



    };


subtest 'get_url() tests' => sub {
        plan tests => 11;

        ok(Robokassa::Pay->can('get_url'), 'method get_url() is available');

        my $robokassa = Robokassa::Pay->new(
            MerchantLogin => 'YourLogin',
            Password1 =>'Password1',
            OutSum =>1000,
            InvDesc => 'Order #123'
        );

        my $link = $robokassa->get_url();

        ok( $link =~ m/^$robokassa->{PayUrl}/, 'URL correct');

        like($link, qr/SignatureValue=eb867b25abb18f1ee0b308fec470f55a/, 'Minimum parameters number: SignatureValue ok');
        like($link, qr/Encoding=utf-8/, 'Minimum parameters number: Encoding ok');
        like($link, qr/MerchantLogin=YourLogin/, 'Minimum parameters number: MerchantLogin ok');
        like($link, qr/InvDesc=Order%20%23123/, 'Minimum parameters number: InvDesc ok');

        unlike($link, qr/Password1=/, 'Minimum parameters number: Password1 ok');
        unlike($link, qr/Password2=/, 'Minimum parameters number: Password2 ok');
        unlike($link, qr/PayURL=/, 'Minimum parameters number: PayURL ok');
        unlike($link, qr/Algorithm=/, 'Minimum parameters number: Algorithm ok');

        $robokassa = Robokassa::Pay->new(
            MerchantLogin => 'YourLogin',
            Password1 =>'Password1',
            Algorithm => 'sha256',
            OutSum =>2000,
            InvDesc => 'Order #123',
            Shp_customerName => 'Ivan',
            Shp_customerLastName => 'Smirnoff'
        );

        $link = $robokassa->get_url();

        like($link, qr/SignatureValue=eb158e8f61c80a62924296c3291cd6c64714e9c007f0efaed51f75fa147610ac/, 'SHA256: SignatureValue ok');

    };


subtest 'get_url_unescaped() tests' => sub {
        plan tests => 11;

        ok(Robokassa::Pay->can('get_url_unescaped'), 'method get_url_unescaped() is available');

        my $robokassa = Robokassa::Pay->new(
            MerchantLogin => 'YourLogin',
            Password1 =>'Password1',
            OutSum =>1000,
            InvDesc => 'Order #123'
        );

        my $link = $robokassa->get_url_unescaped();

        ok( $link =~ m/^$robokassa->{PayUrl}/, 'URL correct');

        like($link, qr/SignatureValue=eb867b25abb18f1ee0b308fec470f55a/, 'Minimum parameters number: SignatureValue ok');
        like($link, qr/Encoding=utf-8/, 'Minimum parameters number: Encoding ok');
        like($link, qr/MerchantLogin=YourLogin/, 'Minimum parameters number: MerchantLogin ok');
        like($link, qr/InvDesc=Order #123/, 'Minimum parameters number: InvDesc ok');

        unlike($link, qr/Password1=/, 'Minimum parameters number: Password1 ok');
        unlike($link, qr/Password2=/, 'Minimum parameters number: Password2 ok');
        unlike($link, qr/PayURL=/, 'Minimum parameters number: PayURL ok');
        unlike($link, qr/Algorithm=/, 'Minimum parameters number: Algorithm ok');

        $robokassa = Robokassa::Pay->new(
            MerchantLogin => 'YourLogin',
            Password1 =>'Password1',
            Algorithm => 'sha256',
            OutSum =>2000,
            InvDesc => 'Order #123',
            Shp_customerName => 'Ivan',
            Shp_customerLastName => 'Smirnoff'
        );

        $link = $robokassa->get_url_unescaped();

        like($link, qr/SignatureValue=eb158e8f61c80a62924296c3291cd6c64714e9c007f0efaed51f75fa147610ac/, 'SHA256: SignatureValue ok');

    };


subtest 'get_form() tests' => sub {
        plan tests => 13;

        ok(Robokassa::Pay->can('get_form'), 'method get_form() is available');

        my $robokassa = Robokassa::Pay->new(
            MerchantLogin => 'YourLogin',
            Password1 =>'Password1',
            OutSum =>1000,
            InvDesc => 'Order #123'
        );

        my %hash = $robokassa->get_form();

        is($hash{SignatureValue}, 'eb867b25abb18f1ee0b308fec470f55a', 'Minimum parameters number: SignatureValue ok');
        is($hash{Encoding}, 'utf-8', 'Minimum parameters number: Encoding ok');
        is($hash{MerchantLogin}, 'YourLogin', 'Minimum parameters number: MerchantLogin');
        is($hash{InvDesc}, 'Order #123', 'Minimum parameters number: Order #123');

        ok(!exists($hash{Password1}), 'Minimum parameters number: Password1 ok');
        ok(!exists($hash{Password2}), 'Minimum parameters number: Password2 ok');
        ok(!exists($hash{PayURL}), 'Minimum parameters number: PayURL ok');
        ok(!exists($hash{Algorithm}), 'Minimum parameters number: Algorithm ok');

        $robokassa -> param(Algorithm => 'sha1');
        %hash = $robokassa->get_form();
        is($hash{SignatureValue}, 'd78b813942ea0567a663455581bb40dd782abe06', 'Hashing algorithm checking: sha1');

        $robokassa -> param(Algorithm => 'sha256');
        %hash = $robokassa->get_form();
        is($hash{SignatureValue}, '4c15604223f914ee9cc6137b94ed5b7b383e6bfc6956fae9f1d3c41922ba47b2', 'Hashing algorithm checking: sha1');

        $robokassa -> param(Algorithm => 'sha384');
        %hash = $robokassa->get_form();
        is($hash{SignatureValue}, '8b69e748547bd4f2f1ecd45418b4568134a0b28e125ce3da1da690bbf524ce653ff941221fb2b6426a3c8b7bdb00ef3d', 'Hashing algorithm checking: sha1');

        $robokassa -> param(Algorithm => 'sha512');
        %hash = $robokassa->get_form();
        is($hash{SignatureValue}, '9086184649f1facebdc600f7d5162d0f6b11b8aecb4fcdb02d5493c87596efb11bc247547cb817dc51a55a3ae174cea1ecc7a0ee652e22d4e2436c66f1a72e8b', 'Hashing algorithm checking: sha1');

    };


subtest 'check_result() tests' => sub {
        plan tests => 4;

        ok(Robokassa::Pay->can('check_result'), 'method check_result() is available');

        my $robokassa = Robokassa::Pay->new(
            SignatureValue => '8a0842e8f7532b693a00e26f1d3bc704',
            Password2 =>'Password2',
            OutSum =>1000
        );
        ok($robokassa->check_result(), 'Minimum parameters number: ok');

        $robokassa = Robokassa::Pay->new();

        ok($robokassa->check_result(
            SignatureValue => '8a0842e8f7532b693a00e26f1d3bc704',
            Password2 =>'Password2',
            OutSum =>1000), 'Params passing: ok'
        );

        $robokassa = Robokassa::Pay->new(
            SignatureValue => '57721f973bf5ab3665546bf618e75f70f98e4e6ec5190921fc5193134c8d643b',
            Password2 =>'Password2',
            OutSum =>1000,
            InvId => 11111,
            Algorithm => 'sha256',
            Shp_customerName => 'Ivan',
            Shp_customerLastName => 'Smirnoff'
        );
        ok($robokassa->check_result(), 'User-defined parameters: ok');
    };
