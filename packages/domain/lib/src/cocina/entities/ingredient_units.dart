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
    for (final u in MeasurementUnit.values) {
      if (u.name == lower || u.label == lower) return u;
    }
    return MeasurementUnit.unidades;
  }
}
