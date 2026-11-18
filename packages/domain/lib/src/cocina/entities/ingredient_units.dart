/// Unidades de medida disponibles para ingredientes.
enum MeasurementUnit {
  unidades,
  kg,
  g,
  litro,
  ml,
  botella,
  lata,
  paquete,
  sobre,
  taza,
  cucharada,
  cucharadita,
  docena,
  libra,
  onza,
  caja,
  bolsa;

  String get label {
    const labels = {
      unidades: 'unidades',
      kg: 'kg',
      g: 'g',
      litro: 'L',
      ml: 'ml',
      botella: 'botella',
      lata: 'lata',
      paquete: 'paquete',
      sobre: 'sobre',
      taza: 'taza',
      cucharada: 'cucharada',
      cucharadita: 'cucharadita',
      docena: 'docena',
      libra: 'libra',
      onza: 'onza',
      caja: 'caja',
      bolsa: 'bolsa',
    };
    return labels[this] ?? name;
  }

  /// Devuelve la unidad correspondiente a un string.
  static MeasurementUnit fromString(String s) {
    final lower = s.toLowerCase().trim();
    const aliases = {
      'u': MeasurementUnit.unidades,
      'ud': MeasurementUnit.unidades,
      'uds': MeasurementUnit.unidades,
      'und': MeasurementUnit.unidades,
      'unidad': MeasurementUnit.unidades,
      'unidades': MeasurementUnit.unidades,
      'l': MeasurementUnit.litro,
      'lt': MeasurementUnit.litro,
      'lts': MeasurementUnit.litro,
      'ltr': MeasurementUnit.litro,
      'litro': MeasurementUnit.litro,
      'litros': MeasurementUnit.litro,
      'mililitro': MeasurementUnit.ml,
      'mililitros': MeasurementUnit.ml,
      'gr': MeasurementUnit.g,
      'grs': MeasurementUnit.g,
      'gramo': MeasurementUnit.g,
      'gramos': MeasurementUnit.g,
      'kilo': MeasurementUnit.kg,
      'kilos': MeasurementUnit.kg,
      'kilogramo': MeasurementUnit.kg,
      'kilogramos': MeasurementUnit.kg,
      'cda': MeasurementUnit.cucharada,
      'cdas': MeasurementUnit.cucharada,
      'cucharadas': MeasurementUnit.cucharada,
      'cdta': MeasurementUnit.cucharadita,
      'cdtas': MeasurementUnit.cucharadita,
      'cucharaditas': MeasurementUnit.cucharadita,
      'tazas': MeasurementUnit.taza,
      'docenas': MeasurementUnit.docena,
      'lb': MeasurementUnit.libra,
      'lbs': MeasurementUnit.libra,
      'libras': MeasurementUnit.libra,
      'oz': MeasurementUnit.onza,
      'onzas': MeasurementUnit.onza,
      'botellas': MeasurementUnit.botella,
      'latas': MeasurementUnit.lata,
      'paquetes': MeasurementUnit.paquete,
      'sobres': MeasurementUnit.sobre,
      'cajas': MeasurementUnit.caja,
      'bolsas': MeasurementUnit.bolsa,
    };
    final aliased = aliases[lower];
    if (aliased != null) return aliased;

    for (final u in MeasurementUnit.values) {
      if (u.name.toLowerCase() == lower || u.label.toLowerCase() == lower) {
        return u;
      }
    }
    return MeasurementUnit.unidades;
  }
}
