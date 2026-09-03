import 'package:meta/meta.dart';

/// Company legal and financial credentials used in contracts, proposals, and
/// invoices.
@immutable
class CompanyDetails {
  const CompanyDetails({
    this.company = '',
    this.name = '',
    this.bin = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.address = '',
    this.city = '',
    this.bankName = '',
    this.bankAccount = '',
    this.bik = '',
  });

  factory CompanyDetails.fromJson(Map<String, dynamic> json) {
    return CompanyDetails(
      company: '${json['company'] ?? ''}'.trim(),
      name: '${json['name'] ?? json['company_name'] ?? ''}'.trim(),
      bin: '${json['bin'] ?? json['tax_id'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? json['phone_no'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}'.trim(),
      website: '${json['website'] ?? ''}'.trim(),
      address: '${json['address'] ?? json['address_line1'] ?? ''}'.trim(),
      city: '${json['city'] ?? ''}'.trim(),
      bankName: '${json['bank_name'] ?? json['bankName'] ?? ''}'.trim(),
      bankAccount:
          '${json['bank_account'] ?? json['bankAccount'] ?? json['iban'] ?? ''}'
              .trim(),
      bik: '${json['bik'] ?? json['bic'] ?? json['branch_code'] ?? ''}'.trim(),
    );
  }

  final String company;
  final String name;
  final String bin;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String city;
  final String bankName;
  final String bankAccount;
  final String bik;

  CompanyDetails copyWith({
    String? company,
    String? name,
    String? bin,
    String? phone,
    String? email,
    String? website,
    String? address,
    String? city,
    String? bankName,
    String? bankAccount,
    String? bik,
  }) {
    return CompanyDetails(
      company: company ?? this.company,
      name: name ?? this.name,
      bin: bin ?? this.bin,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      address: address ?? this.address,
      city: city ?? this.city,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      bik: bik ?? this.bik,
    );
  }

  Map<String, dynamic> toJson() => {
    if (company.isNotEmpty) 'company': company,
    if (name.isNotEmpty) 'name': name,
    if (bin.isNotEmpty) 'bin': bin,
    if (phone.isNotEmpty) 'phone': phone,
    if (email.isNotEmpty) 'email': email,
    if (website.isNotEmpty) 'website': website,
    if (address.isNotEmpty) 'address': address,
    if (city.isNotEmpty) 'city': city,
    if (bankName.isNotEmpty) 'bank_name': bankName,
    if (bankAccount.isNotEmpty) 'bank_account': bankAccount,
    if (bik.isNotEmpty) 'bik': bik,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanyDetails &&
          runtimeType == other.runtimeType &&
          company == other.company &&
          name == other.name &&
          bin == other.bin &&
          phone == other.phone &&
          email == other.email &&
          website == other.website &&
          address == other.address &&
          city == other.city &&
          bankName == other.bankName &&
          bankAccount == other.bankAccount &&
          bik == other.bik;

  @override
  int get hashCode => Object.hash(
    company,
    name,
    bin,
    phone,
    email,
    website,
    address,
    city,
    bankName,
    bankAccount,
    bik,
  );
}
