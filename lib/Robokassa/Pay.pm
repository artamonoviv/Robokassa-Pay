package Robokassa::Pay;
use strict;
use warnings;
use utf8;
use Carp qw(croak);
use autouse "Digest::SHA" => qw(sha1_hex sha256_hex sha384_hex sha512_hex);
use autouse "Digest::MD5" => qw(md5_hex);
use autouse "URI::Escape" => qw(uri_escape_utf8);

our $VERSION = '0.001';

sub new {
    my ( $class, %args ) = @_;

    _check_params( \%args );

    my $self = \%args;

    $self->{Encoding}  = 'utf-8' unless ( defined( $self->{Encoding} ) );
    $self->{Algorithm} = 'md5'   unless ( defined( $self->{Algorithm} ) );
    $self->{PayUrl} = 'https://auth.robokassa.ru/Merchant/Index.aspx'
      unless ( defined( $self->{PayUrl} ) );

    bless $self, $class;
}

sub _check_params {
    my $args = $_[0];

    croak 'Recurring payment is not yet supported'
      if ( defined( $args->{Recurring} ) );

    croak 'The second check is not yet supported'
      if ( defined( $args->{OriginId} ) );

    my %available = map { $_ => 1 } qw(
      Email OutSum MerchantLogin Encoding InvDesc InvId
      UserIp IncCurrLabel Culture ExpirationDate OutSumCurrency
      Receipt IsTest Password1 Password2 Algorithm
      PayUrl SignatureValue
    );

    map {
        croak 'Unknown param: ' . $_
          if ( !exists( $available{$_} ) && $_ !~ /^shp_/i )
    } keys %$args;

    croak 'Receipt arg must be a Robokassa::Receipt object'
      if ( exists( $args->{Receipt} ) && !_check_receipt( $args->{Receipt} ) );

    croak 'Unknown hashing algorithm: ' . $args->{Algorithm}
      if ( exists( $args->{Algorithm} )
        && !_check_algorithm( $args->{Algorithm} ) );

    return 1;
}

sub _check_algorithm {
    my $algorithm = $_[0];
    return 1
      if grep { $algorithm eq $_ } qw (md5 sha1 sha256 sha384 sha512);

    return 0;
}

sub _check_mandatory {
    my $self = $_[0];
    map { croak $_. ' is not defined' if ( !defined( $self->{$_} ) ) }
      qw(OutSum MerchantLogin InvDesc Password1);

    return 1;
}

sub _check_receipt {
    my $receipt = $_[0];
    return 0 if ( defined($receipt) && ref($receipt) ne 'Robokassa::Receipt' );
    return 1;
}

sub param {
    my ( $self, %args ) = @_;

    _check_params( \%args );

    $self->{$_} = $args{$_} foreach ( keys %args );

    return 1;
}

sub get_url_unescaped {
    my $self = $_[0];

    my $params = $self->_prepare_params();

    return $self->{PayUrl} . '?'
      . join( '&', map { $_ . '=' . $params->{$_} } keys %$params );
}

sub get_url {
    my $self = $_[0];

    my $params = $self->_prepare_params();

    $params->{Receipt} = uri_escape_utf8( $params->{Receipt} )
      if ( defined( $params->{Receipt} ) );

    return
      $self->{PayUrl} . '?'
      . join( '&',
        map { $_ . '=' . uri_escape_utf8( $params->{$_} ) } keys %$params );
}

sub get_form {
    my $self = $_[0];

    my $params = $self->_prepare_params();

    return %$params;
}

sub check_result {
    my ( $self, %params ) = @_;

    foreach (qw(OutSum SignatureValue Password2 Algorithm)) {
        if ( !defined( $params{$_} ) && defined( $self->{$_} ) ) {
            $params{$_} = $self->{$_};
        }
        elsif ( !defined( $params{$_} ) ) {
            $@ = $_ . ' is not defined';
            return undef;
        }
    }

    my $sign = _create_signature_in( \%params );

    return 1 if ( lc($sign) eq lc( $params{SignatureValue} ) );

    return 0;
}

sub _prepare_params {
    my $self = $_[0];
    $self->_check_mandatory();

    my %params = map { $_ => $self->{$_} } grep { defined( $self->{$_} ) } qw(
      MerchantLogin OutSum InvDesc IncCurrLabel InvId Culture
      Encoding Email ExpirationDate OutSumCurrency UserIp
      Password1 IsTest Algorithm
    );

    $params{Receipt} = $self->{Receipt}->json()
      if ( defined( $self->{Receipt} ) );

    $params{SignatureValue} = _create_signature_out( \%params );

    $params{Receipt} = Encode::decode_utf8( $params{Receipt} )
      if ( defined( $params{Receipt} ) );

    map { delete( $params{$_} ) } qw (Algorithm Password1);

    return \%params;
}

sub _create_signature_out {
    my $params = $_[0];

    my @data =
      ( $params->{MerchantLogin}, $params->{OutSum} );

    ( defined( $params->{InvId} ) )
      ? push @data, $params->{InvId}
      : push @data, '';

    push @data, $params->{OutSumCurrency}
      if ( defined( $params->{OutSumCurrency} ) );

    push @data, $params->{UserIp}  if ( defined( $params->{UserIp} ) );
    push @data, $params->{Receipt} if ( defined( $params->{Receipt} ) );
    push @data, $params->{Password1};

    push @data, map { $_ . '=' . $params->{$_} }
      sort grep { $_ =~ /^shp_/i } keys %$params;

    my $data = join( ':', @data );

    return _hashing( $params->{Algorithm}, $data );
}

sub _hashing {
    my $algorithm = $_[0];
    no strict 'refs';
    my $hashing = *{ $algorithm . '_hex' };
    return &$hashing( $_[1] );
}

sub _create_signature_in {
    my $params = $_[0];
    $params->{InvId} = ( !exists( $params->{InvId} ) ) ? '' : $params->{InvId};
    my @data = ( $params->{OutSum},, $params->{Password2} );
    push @data, map { $_ . '=' . $params->{$_} }
      sort grep { $_ =~ /^shp_/i } keys %$params;

    my $data = join( ':', @data );

    return _hashing( $params->{Algorithm}, $data );
}

=pod

=encoding UTF-8

=head1 NAME

Robokassa::Pay - Payment gateway for Robokassa.ru (L<https://robokassa.ru/en>) service.

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use Robokassa::Pay;

    # Creating a payment object
    my $robokassa = Robokassa::Pay->new(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000,
        InvDesc => 'Order #123'
    );

    # Create a payment link for a customer
    my $link = $robokassa->get_url();
    print "Please click <a href='$link'>here</a> to pay your order";

    # Checking a Robokassa's answer
    use CGI;
    my $cgi=CGI->new();

    my $robokassa = Robokassa::Pay->new(
        Password2 =>'your password2',
        InvId => $cgi->param('InvId'),
        OutSum => $cgi->param('OutSum'),
        SignatureValue => $cgi->param('SignatureValue')
    );

    if($robokassa->check_result())
    {
        print 'OK'.$cgi->param('InvId'); # Say 'OK' to Robokassa
    }

    # Testing a payment interface and using a payment form
    my $robokassa = Robokassa::Pay->new(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        IsTest => 1
    );

    $robokassa -> param (OutSum => 1000, InvDesc => 'Order #123');

    my %fields = $robokassa->get_form();
    print "<form action='$robokassa->{PayUrl}'>";
    foreach (keys %fields)
    {
        print "<input type='hidden' name='$_' value='$fields{$_}'>";
    }
    print "<input type='submit' value='Click to test payment interface'></form>";

    # Show an error text of the last failed operation
    print $@;

=head1 DESCRIPTION

Robokassa L<https://www.robokassa.ru/en/> is one of the largest Russian payment services.

Robokassa::Pay is intended to provide a payment mechanism through Robokassa for website customers.

The module makes easy to main steps of payments:
1. Passes payment data and redirect customer to Robokassa interface (payment initialisation).
2. Checks a Robokassa answer (after customer payment) to complete order payment (payment check).

If you strictly need to comply with the Russian law 54-FZ please refer to L<Robokassa::Receipt>.

=head1 METHODS

=head2 new (%args)

    # Create a new payment object
    my %args =(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000,
        InvDesc => 'Order #123'
    );
    my $robokassa = Robokassa::Pay->new(%args);

    # or

    my $robokassa = Robokassa::Pay->new(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000,
        InvDesc => 'Order #123'
     );

Arguments that may be passed include:

=over 3

=item MerchantLogin

A shop identifier for Robokassa. Mandatory for a payment initialization.

=item Password1

Mandatory for a payment initialization.

MerchantLogin (shop identifier), Password1, Password2, Algorithm can be set in the section "Technical Settings" of a Robokassa client account.

=item Password2

Mandatory for a payment check.

=item Algorithm

Hashing algorithm. Only 'md5', 'sha1', 'sha256', 'sha384', 'sha512' are supported. 'md5' by default.

=item InvDesc

Description of the purchase. Only English or Russian letters, digits and punctuation marks may be used. Maximum 100 characters. Mandatory for a payment initialization.

=item OutSum

Means the amount payable (in other words, the price of the order placed by the client). Mandatory for a payment initialization.

=item Receipt

Contents of the customer order (a list of order items). With the system of taxation. In most cases, you already MUST use this parameter inside the Russian taxation area. Almost mandatory for a payment initialization. Please refer to L<Robokassa::Receipt>.

=item PayURL

Robokassa payment URL. Default is 'https://auth.robokassa.ru/Merchant/Index.aspx'.

=item Encoding

Encoding of passed data. Default is 'utf-8'.

=item IsTest

Signalizes of test payment if set to 1.

=item InvId

Means your invoice number. The optional parameter, but Robokassa strongly recommends using it.

=item Email

The buyer’s E-Mail is automatically inserted into Robokassa payment form. An operation check will be sent to the email.

=item UserIp

IPv4 address of a customer for additional security checking.

=item IncCurrLabel, Culture, ExpirationDate, OutSumCurrency

Please follow Robokassa docs for more info - L<https://docs.robokassa.ru/en>.

=back

=head2 param (%args)

Set payment object parameters. See the above section.

    my $robokassa = Robokassa::Pay->new();
    $robokassa -> param(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000
    )
    $robokassa -> param(InvDesc => 'Order #123');

=head2 get_url()

Creates a url for payment. A customer should follow the url to pay an order.

    # Create a payment link for a customer
    my $link = $robokassa->get_url();
    print "Please click <a href='$link'>here</a> to pay your order";

=head2 get_url_unescaped()

Works like 'get_url' but unescapes url's data. It may be necessary for works with frameworks, ORMs, etc.

=head2 get_form()

Creates a hash of form fields for a customer.

    my %fields = $robokassa->get_form();
    print "<form action='$robokassa->{PayUrl}'>";
    foreach (keys %fields)
    {
        print "<input type='hidden' name='$_' value='$fields{$_}'>";
    }
    print "<input type='submit' value='Click to pay'></form>";


=head2 check_result (%args)

Checks a Robokassa answer. Returns 1 if a signature is correct. Mandatory parameters are Password2, OutSum, SignatureValue. You can pass them by new(), param() or check_result() methods.

    use CGI;
    my $cgi=CGI->new();

    my $robokassa = Robokassa::Pay->new(
        Password2 =>'your password2',
        InvId => $cgi->param('InvId'),
        OutSum => $cgi->param('OutSum'),
        SignatureValue => $cgi->param('SignatureValue')
    );

    if($robokassa->check_result())
    {
        print 'OK'.$cgi->param('InvId'); # Say 'OK' to Robokassa
    }

=head2 User Parameters

Robokassa allows passing user-defined parameters to the payment interface. These are those parameters that Robokassa never processes but always returns to the store in response messages.

Following Robokassa docs these parameters always start with: Shp_; SHP_; shp_.

You must pass these parameters into check_result().

    # Stage 1: payment initialisation
    my $robokassa = Robokassa::Pay->new();
    $robokassa -> param(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000,
        InvDesc => 'Order #123',
        Shp_customerName => 'Ivan';
        Shp_customerLastName => 'Smirnoff';
    )

    # Create a payment link for a customer
    my $link = $robokassa->get_url(); # A link will include Shp_customerName and Shp_customerLastName
    print "Please click <a href='$link'>here</a> to pay your order";

    # Stage 2: payment check
    use CGI;
    my $cgi=CGI->new();

    my $robokassa = Robokassa::Pay->new(
        Password2 =>'your password2',
        InvId => $cgi->param('InvId'),
        OutSum => $cgi->param('OutSum'),
        SignatureValue => $cgi->param('SignatureValue'),
        Shp_customerName => $cgi->param('Shp_customerName'),
        Shp_customerLastName => $cgi->param('Shp_customerLastName')
    );

    if($robokassa->check_result())
    {
        print 'OK'.$cgi->param('InvId'); # Say 'OK' to Robokassa
    }

=head1 BUGS AND LIMITATIONS

The package is intended only for payment functions. It cannot work with other Robokassa API methods (like SMS sending).

=head1 SEE ALSO

L<Robokassa::Receipt> - helps to create Robokassa Receipt object and to meet the Russian law 54-FZ.

=head1 AUTHOR

Ivan Artamonov, <ivan.s.artamonov {at} gmail.com>

=head1 LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.

=cut

1;
