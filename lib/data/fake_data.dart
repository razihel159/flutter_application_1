import 'dart:math';

class Municipality {
  final String name;
  final int registeredUsers;
  Municipality(this.name, this.registeredUsers);
}

class Province {
  final String name;
  final List<Municipality> municipalities;
  Province(this.name, this.municipalities);

  int get totalRegisteredUsers =>
      municipalities.fold(0, (sum, item) => sum + item.registeredUsers);
}

class CountryDetails {
  final String name;
  final List<Province> provinces;
  CountryDetails(this.name, this.provinces);

  int get totalRegisteredUsers =>
      provinces.fold(0, (sum, item) => sum + item.totalRegisteredUsers).clamp(500, 15000);
}

CountryDetails? getDetailedDataForCountry(String name) {
  if (name == 'NOT_FOUND') {
    return CountryDetails(name, [
      Province('Debug Province', [Municipality('Debug Municipality', 1000)])
    ]);
  }

  // Ginagamit ang name.hashCode para laging pareho ang "random" number ng isang lugar
  final random = Random(name.hashCode);

  // 1. Base User Count for Region (10,000 - 15,000)
  int regionTotal = 10000 + random.nextInt(5001);

  // 2. Generate Provinces (2 to 4)
  int provinceCount = random.nextInt(3) + 2;
  
  // Distribute regionTotal among provinces
  List<double> provWeights = List.generate(provinceCount, (_) => random.nextDouble() + 0.5);
  double totalProvWeight = provWeights.reduce((a, b) => a + b);

  final provinces = List.generate(provinceCount, (i) {
    int provinceTotal = (regionTotal * (provWeights[i] / totalProvWeight)).round();

    // 3. Generate Municipalities (3 to 7)
    int muniCount = random.nextInt(5) + 3;
    
    // Distribute provinceTotal among municipalities
    List<double> muniWeights = List.generate(muniCount, (_) => random.nextDouble() + 0.5);
    double totalMuniWeight = muniWeights.reduce((a, b) => a + b);

    final municipalities = List.generate(muniCount, (j) {
      int muniUsers = (provinceTotal * (muniWeights[j] / totalMuniWeight)).round();
      return Municipality(
        'Muni ${j + 1}',
        muniUsers,
      );
    });
    return Province('Prov $i', municipalities);
  });

  return CountryDetails(name, provinces);
}

int getSimulatedUserCount(String areaName, String level) {
  // Use hashCode to keep numbers consistent for the same area
  final random = Random(areaName.hashCode);

  // Use a wider random range for Regions (1,000 to 15,999)
  final int regionBase = 1000 + random.nextInt(15000);

  if (level == 'region') {
    return regionBase;
  } else if (level == 'province') {
    // Return 20% - 40% of the "parent" region total
    double percent = 0.20 + random.nextDouble() * 0.20;
    return (regionBase * percent).round();
  } else {
    // For municipalities, use a direct random range for more variety.
    return 100 + random.nextInt(1401); // Generates a number between 100 and 1500.
  }
}