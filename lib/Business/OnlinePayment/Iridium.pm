package Business::OnlinePayment::Iridium;

use warnings;
use strict;
use Moose;
use aliased 'Business::OnlinePayment::Iridium::Action::GetGatewayEntryPoints';
use aliased 'Business::OnlinePayment::Iridium::Action::GetCardType';
use aliased 'Business::OnlinePayment::Iridium::Action::CardDetailsTransaction';
use aliased
   'Business::OnlinePayment::Iridium::Action::ThreeDSecureAuthentication';
use Carp 'carp';
use constant {
  FIELD_MAP => {
    'login'           => 'MerchantID',
    'password'        => 'Password',
    'card_number'     => 'CardNumber',
    'name_on_card'    => 'CardName',
    'amount'          => 'Amount',
    'invoice_number'  => 'OrderID',
    'description'     => 'OrderDescription',
    'action'          => 'TransactionType',
    'expiration'      => 'Expiration',
    'cross_reference' => 'CrossReference',
    'pares'           => 'PaRES',
  },
  ACTION_MAP => {
    'normal authorization' => 'SALE',
    'refund ammount'       => 'REFUND',
    'authorization only'   => 'STORE',
    'post authorization'   => 'PREAUTH',
  },
  CARD_TYPE_MAP => {
    'american express' => 'AMEX',
    'visa'             => 'VISA',
    'visa card'        => 'VISA',
    'visa credit'      => 'VISA',
    'visa electron'    => 'UKE',
    'visa debit'       => 'UKE',
    'mastercard'       => 'MC',
    'maestro'          => 'SWITCH',
    'switch'           => 'SWITCH',
    'switch solo'      => 'SWITCH',
    'diners club'      => 'DC',
    'jcb'              => 'JB',
  }
};

extends 'Business::OnlinePayment';

our $VERSION = '0.02';

has 'require_3d' => (
  isa => 'Bool',
  is  => 'rw', default => '0'
);

has 'forward_to' => (
  isa => 'Str',
  is  => 'rw', required => '0'
);

has 'authentication_key' => (
  isa => 'Str',
  is  => 'rw', required => '0'
);

has 'cross_reference' => (
  isa => 'Str',
  is  => 'rw', required => '0'
);

=head1 NAME

Business::OnlinePayment::Iridium - Iridium backend for Business::OnlinePayment

=head1 SYNOPSIS

  use Business::OnlinePayment;

  my $tx = Business::OnlinePayment->new('Iridium');
  $tx->content(
     'login'          => 'MerchantID',
     'password'       => 'Password',
     'card_number'    => '4976000000003436',
     'name_on_card'   => 'John Watson',
     'expiration'     => '12/12',
     'invoice_number' => 'TUID',
     'amount'         => '123.23',
     'action'         => 'normal authorization'
  );
  $tx->submit;

  if ($tx->is_success) {
    print "Card processed successfully: " . $tx->authorization . "\n";
  } else {
    print "Card was rejected: " . $tx->error_message . "\n";
  }

=head1 DESCRIPTION

Backend that allows you to easily make payments via the Iridium system.

=head1 METHODS

=cut

sub _check_amount_field {
  my %content = shift->content;
  confess 'missing required field amount'
    unless exists $content{'amount'}
      || lc($content{'action'}) eq 'authorization only';
}

sub _format_amount {
  my ( $self, $amount ) = @_;
  $amount = sprintf("%.2f",$amount);
  $amount =~ s/\.//;
  return $amount;
}

sub _submit_callback {
  my ( $self, $res_result, $res_data ) = @_;
  if ( $self->result_code == 0 ) {
    $self->is_success(1);
    $self->authorization($res_data->{'AuthCode'});
  } elsif ( $self->result_code == 20
            && $res_result->{'PreviousTransactionResult'}->{'StatusCode'} == 0
    ) {
    $self->is_success(1);
    $self->authorization($res_data->{'AuthCode'});
  } elsif ( $self->result_code == 3 ) {
    $self->require_3d(1);
    my $threeD_data = $res_data->{'ThreeDSecureOutputData'};
    $self->forward_to($threeD_data->{'ACSURL'});
    $self->authentication_key($threeD_data->{'PaREQ'});
    $self->cross_reference($res_data->{'CrossReference'});
  } else {
    $self->is_success(0);
    $self->error_message($res_result->{'Message'});
  }
}

override remap_fields => sub {
    my ( $self, $map ) = @_;
    my %content = $self->content();
    foreach (keys %$map) {
        $content{$map->{$_}} = $content{$_};
    }
    $self->content(%content);
};

=head2 get_entry_points

NOTE: Not supported yet.

Returns the details of all the gateway entry points.

=cut

sub get_entry_points { confess 'Not supported yet.' }

=head2 get_card_type

This allows the merchant to determine the card type of the card in question.

=cut

sub get_card_type {
  my $self = shift;
  $self->required_fields(qw/login password card_number/);
  my %data = $self->remap_fields(FIELD_MAP);

  my $tx = GetCardType->new(
        map { $_ => $data{$_} } qw(MerchantID Password CardNumber)
  );
  my $res = $tx->request;
  $res = $res->{'soap:Body'}->{'GetCardTypeResponse'};
  my $res_result = $res->{'GetCardTypeResult'};
  my $res_data   = $res->{'GetCardTypeOutputData'};
  $self->server_response($res);
  $self->result_code($res_result->{'StatusCode'});

  if ( $self->result_code == 0 ) {
    $self->is_success(1);
    return $res_data->{'CardTypeData'}->{'CardType'}
  } else {
    $self->is_success(0);
    return 'Failed: ' . $res_result->{'Message'};
  }
}

=head2 submit

=cut

sub submit {
  my $self = shift;
  $self->required_fields(qw/login password card_number name_on_card
     expiration invoice_number action amount/);
  my %data = $self->remap_fields(FIELD_MAP);
  my $tx_type = lc($data{'TransactionType'});
  confess "Action 'authorization only' is not supported yet."
    if $tx_type eq 'authorization only';
  confess 'To run in test mode, use test card details from docs.'
    if $self->test_transaction;

  my $amount = $self->_format_amount($data{'Amount'});
  $data{'Expiration'} =~ m|(\d{2})/?(\d{2})|;
  my ($expire_month, $expire_year) = ($1, $2);

  my $tx = CardDetailsTransaction->new(
        ( map { $_ => $data{$_} }
            qw(MerchantID Password CardNumber CardName OrderID) ),
        TransactionType => ACTION_MAP->{$tx_type},
        Amount          => $amount,
        ExpireMonth     => $expire_month,
        ExpireYear      => $expire_year,
  );
  my $res = $tx->request;
  $res = $res->{'soap:Body'}->{'CardDetailsTransactionResponse'};
  my $res_result = $res->{'CardDetailsTransactionResult'};
  $self->server_response($res);
  $self->result_code($res_result->{'StatusCode'});

  $self->_submit_callback($res_result, $res->{'TransactionOutputData'});
}

=head2 submit_3d

=cut

sub submit_3d {
  my $self = shift;
  $self->required_fields(qw/login password cross_reference pares/);
  my %data = $self->remap_fields(FIELD_MAP);

  my $tx = ThreeDSecureAuthentication->new(
        ( map { $_ => $data{$_} }
            qw(MerchantID Password CrossReference PaRES) ),
  );
  my $res = $tx->request;
  $res = $res->{'soap:Body'}->{'ThreeDSecureAuthenticationResponse'};
  my $res_result = $res->{'ThreeDSecureAuthenticationResult'};
  my $res_data   = $res->{'TransactionOutputData'};
  $self->server_response($res);
  $self->result_code($res_result->{'StatusCode'});

  if ( $self->result_code == 0 ) {
    carp "Albeit 3D secure auth didn't pass, the transaction will be processed"
      if $res_data->{'ThreeDSecureAuthenticationCheckResult'} eq 'UNKNOWN';
    $self->is_success(1);
    $self->authorization($res_data->{'AuthCode'});
  } else {
    $self->is_success(0);
    $self->error_message($res_result->{'Message'});
  }
}

=head2 test_transaction

Please note that ONLY test card details provided in docs will
work in test mode - real card numbers will NOT work.

=head2 is_success

Returns true if the transaction was submitted successfully, false if it failed
(or undef if it has not been submitted yet).

=head2 result_code

Returns the StatusCode.

=head2 error_message

If the transaction has been submitted but was not accepted, this function will
return the provided error message (if any).

=head2 authorization

If the transaction has been submitted and accepted, this function will provide
you with the authorization code.

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-onlinepayment-iridium at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-OnlinePayment-Iridium>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::OnlinePayment::Iridium

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-OnlinePayment-Iridium>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-OnlinePayment-Iridium>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-OnlinePayment-Iridium>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-OnlinePayment-Iridium>

=back

=head1 SEE ALSO

L<Business::OnlinePayment>

=head1 AUTHOR

  wreis: Wallace Reis <reis.wallace@gmail.com>

=head1 ACKNOWLEDGEMENTS

  To Airspace Software Ltd <http://www.airspace.co.uk>, for the sponsorship.

  To Simon Elliott, for comments and questioning the design.

=head1 LICENSE

  This library is free software under the same license as perl itself.

=cut

1;
