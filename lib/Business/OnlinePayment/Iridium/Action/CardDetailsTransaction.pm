package Business::OnlinePayment::Iridium::Action::CardDetailsTransaction;

use Moose;

with 'Business::OnlinePayment::Iridium::Action';

has 'OrderID' => (
  isa => 'Str',
  is  => 'rw', required => '1'
);

has 'OrderDescription' => (
  isa => 'Str',
  is  => 'rw', required => '0'
);

has 'TransactionType' => (
  isa => 'Str',
  is  => 'rw', required => '1'
);

has 'CardName' => (
  isa => 'Str',
  is  => 'rw', required => '1'
);

has 'CardNumber' => (
  isa => 'Int',
  is  => 'rw', required => '1'
);

has 'ExpireMonth' => (
  isa => 'Int',
  is  => 'rw', required => '1'
);

has 'ExpireYear' => (
  isa => 'Int',
  is  => 'rw', required => '1'
);

has 'Amount' => (
  isa => 'Int',
  is  => 'rw', required => '1'
);

sub _build__type { return 'CardDetailsTransaction' }

sub template {
  return <<DATA;
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
<soap:Body>
  <CardDetailsTransaction xmlns="https://www.thepaymentgateway.net/">
    <PaymentMessage>
      <MerchantAuthentication MerchantID="[% MerchantID %]" Password="[% Password %]" />
      <TransactionDetails Amount="[% Amount %]" CurrencyCode="[% CurrencyCode %]">
        <MessageDetails TransactionType="[% TransactionType %]" />
        <OrderID>[% OrderID %]</OrderID>
        <OrderDescription>[% OrderDescription %]</OrderDescription>
      </TransactionDetails>
      <CardDetails>
        <CardName>[% CardName %]</CardName>
        <CardNumber>[% CardNumber %]</CardNumber>
        <ExpiryDate Month="[% ExpireMonth %]" Year="[% ExpireYear %]" />
        <StartDate Month="[% StartMonth %]" Year="[% StartYear %]" />
        <CV2>[% CV2 %]</CV2>
        <IssueNumber>[% IssueNumber %]</IssueNumber>
      </CardDetails>
      <CustomerDetails>
        <BillingAddress>
          <Address1>[% Address1 %]</Address1>
          <Address2>[% Address2 %]</Address2>
          <Address3>[% Address3 %]</Address3>
          <Address4>[% Address4 %]</Address4>
          <City>[% City %]</City>
          <State>[% State %]</State>
          <PostCode>[% PostCode %]</PostCode>
          <CountryCode>[% CountryCode %]</CountryCode>
        </BillingAddress>
        <EmailAddress>[% EmailAddress %]</EmailAddress>
        <PhoneNumber>[% PhoneNumber %]</PhoneNumber>
      </CustomerDetails>
      <PassOutData>[% PassOutData %]</PassOutData>
    </PaymentMessage>
  </CardDetailsTransaction>
</soap:Body>
</soap:Envelope>
DATA
}

1;
