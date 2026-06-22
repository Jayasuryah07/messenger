class Lead {
  final int id;
  final String mobileNo;
  final String message;
  final String? dataImage;
  final String fileAttached;
  final String dataStatus;
  final String dataCreated;
  final String? followupDate;
  final String? followupTime;

  Lead({
    required this.id,
    required this.mobileNo,
    required this.message,
    this.dataImage,
    required this.fileAttached,
    required this.dataStatus,
    required this.dataCreated,
    this.followupDate,
    this.followupTime,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as int,
      mobileNo: (json['mobile_no'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      dataImage: json['data_image'] as String?,
      fileAttached: (json['file_attached'] ?? '').toString(),
      dataStatus: (json['data_status'] ?? '').toString(),
      dataCreated: (json['data_created'] ?? '').toString(),
      followupDate: json['followup_date'] as String?,
      followupTime: json['followup_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mobile_no': mobileNo,
      'message': message,
      'data_image': dataImage,
      'file_attached': fileAttached,
      'data_status': dataStatus,
      'data_created': dataCreated,
      'followup_date': followupDate,
      'followup_time': followupTime,
    };
  }

  bool get hasImage {
    if (dataImage == null || dataImage!.isEmpty) return false;
    final path = dataImage!.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  bool get hasPdf {
    if (dataImage == null || dataImage!.isEmpty) return false;
    final path = dataImage!.toLowerCase();
    return path.endsWith('.pdf');
  }

  String get mediaUrl {
    if (dataImage == null || dataImage!.isEmpty) return '';
    return 'https://agsdemo.in/emapi/public/assets/images/data_images/$dataImage';
  }
}

class CompanyStatus {
  final int id;
  final String companyStatus;

  CompanyStatus({
    required this.id,
    required this.companyStatus,
  });

  factory CompanyStatus.fromJson(Map<String, dynamic> json) {
    return CompanyStatus(
      id: json['id'] as int,
      companyStatus: (json['companyStatus'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyStatus': companyStatus,
    };
  }
}
