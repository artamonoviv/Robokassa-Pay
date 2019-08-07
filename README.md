# NAME

Robokassa::Pay - Payment gateway for Robokassa.ru ([https://robokassa.ru/en](https://robokassa.ru/en)) service.

# VERSION

version 0.001

# SYNOPSIS

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

# DESCRIPTION

Robokassa [https://www.robokassa.ru/en/](https://www.robokassa.ru/en/) is one of the largest Russian payment services.

Robokassa::Pay is intended to provide a payment mechanism through Robokassa for website customers.

The module makes easy to main steps of payments:
1\. Passes payment data and redirect customer to Robokassa interface (payment initialisation).
2\. Checks a Robokassa answer (after customer payment) to complete order payment (payment check).

If you strictly need to comply with the Russian law 54-FZ please refer to [Robokassa::Receipt](https://metacpan.org/pod/Robokassa::Receipt).

# METHODS

## new (%args)

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

- MerchantLogin

    A shop identifier for Robokassa. Mandatory for a payment initialization.

- Password1

    Mandatory for a payment initialization.

    MerchantLogin (shop identifier), Password1, Password2, Algorithm can be set in the section "Technical Settings" of a Robokassa client account.

- Password2

    Mandatory for a payment check.

- Algorithm

    Hashing algorithm. Only 'md5', 'sha1', 'sha256', 'sha384', 'sha512' are supported. 'md5' by default.

- InvDesc

    Description of the purchase. Only English or Russian letters, digits and punctuation marks may be used. Maximum 100 characters. Mandatory for a payment initialization.

- OutSum

    Means the amount payable (in other words, the price of the order placed by the client). Mandatory for a payment initialization.

- Receipt

    Contents of the customer order (a list of order items). With the system of taxation. In most cases, you already MUST use this parameter inside the Russian taxation area. Almost mandatory for a payment initialization. Please refer to [Robokassa::Receipt](https://metacpan.org/pod/Robokassa::Receipt).

- PayURL

    Robokassa payment URL. Default is 'https://auth.robokassa.ru/Merchant/Index.aspx'.

- Encoding

    Encoding of passed data. Default is 'utf-8'.

- IsTest

    Signalizes of test payment if set to 1.

- InvId

    Means your invoice number. The optional parameter, but Robokassa strongly recommends using it.

- Email

    The buyer’s E-Mail is automatically inserted into Robokassa payment form. An operation check will be sent to the email.

- UserIp

    IPv4 address of a customer for additional security checking.

- IncCurrLabel, Culture, ExpirationDate, OutSumCurrency

    Please follow Robokassa docs for more info - [https://docs.robokassa.ru/en](https://docs.robokassa.ru/en).

## param (%args)

Set payment object parameters. See the above section.

    my $robokassa = Robokassa::Pay->new();
    $robokassa -> param(
        MerchantLogin => 'your login',
        Password1 =>'your password1',
        OutSum =>1000
    )
    $robokassa -> param(InvDesc => 'Order #123');

## get\_url()

Creates a url for payment. A customer should follow the url to pay an order.

    # Create a payment link for a customer
    my $link = $robokassa->get_url();
    print "Please click <a href='$link'>here</a> to pay your order";

## get\_url\_unescaped()

Works like 'get\_url' but unescapes url's data. It may be necessary for works with frameworks, ORMs, etc.

## get\_form()

Creates a hash of form fields for a customer.

    my %fields = $robokassa->get_form();
    print "<form action='$robokassa->{PayUrl}'>";
    foreach (keys %fields)
    {
        print "<input type='hidden' name='$_' value='$fields{$_}'>";
    }
    print "<input type='submit' value='Click to pay'></form>";

## check\_result (%args)

Checks a Robokassa answer. Returns 1 if a signature is correct. Mandatory parameters are Password2, OutSum, SignatureValue. You can pass them by new(), param() or check\_result() methods.

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

## User Parameters

Robokassa allows passing user-defined parameters to the payment interface. These are those parameters that Robokassa never processes but always returns to the store in response messages.

Following Robokassa docs these parameters always start with: Shp\_; SHP\_; shp\_.

You must pass these parameters into check\_result().

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

# BUGS AND LIMITATIONS

The package is intended only for payment functions. It cannot work with other Robokassa API methods (like SMS sending).

# SEE ALSO

[Robokassa::Receipt](https://metacpan.org/pod/Robokassa::Receipt) - helps to create Robokassa Receipt object and to meet the Russian law 54-FZ.

# AUTHOR

Ivan Artamonov, &lt;ivan.s.artamonov {at} gmail.com>

# LICENSE AND COPYRIGHT

This software is copyright (c) 2019 by Ivan Artamonov.

This is free software; you can redistribute it and/or modify it under the same terms as the Perl 5 programming language system itself.
