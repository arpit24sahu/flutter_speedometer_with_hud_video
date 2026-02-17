import 'package:speedometer/features/labs/models/gauge_customization.dart';

const Dial defaultDial = Dial(
  id: 'classic_colored_dial',
  name: 'Classic',
  style: DialStyle.analog,
  assetType: AssetType.network,
  path: 'https://i.ibb.co/QFtc3pnm/SHARMA-2.png',
  needleMinAngle: 0,
  needleMaxAngle: 240,
);

const Needle defaultNeedle = Needle(
  id: 'classic_needle_black_1',
  name: "Classic 1",
  assetType: AssetType.network,
  path: 'https://i.ibb.co/kgpT3qxx/classic-needle-1.png',
  color: 'black',
);


final List<Needle> _needles = [
  Needle(
    id: 'classic_needle_black_1',
    name: "Classic 1",
    assetType: AssetType.network,
    path: 'https://i.ibb.co/kgpT3qxx/classic-needle-1.png',
    color: 'black',
  ),
  Needle(
    id: 'classic_needle_black',
    name: "Classic Thin",
    assetType: AssetType.network,
    path: 'https://i.ibb.co/bMD3KpK0/needle.png',
    color: 'black',
  ),
  Needle(
    id: 'compass_needle_red_white',
    name: "Compass",
    assetType: AssetType.network,
    path: 'https://i.ibb.co/Y4BGgW8K/compass-needle.png',
    color: 'red',
  ),
  Needle(
    id: 'pen_needle_black',
    name: "Pen",
    assetType: AssetType.network,
    path: 'https://i.ibb.co/hTbLQnK/pen-needle.png',
    color: 'black',
  ),
];

final List<Dial> _dials = [
  // const Dial(
  //   id: 'classic_dial',
  //   name: "Old",
  //   style: DialStyle.analog,
  //   assetType: AssetType.network,
  //   path: 'https://i.ibb.co/whLrrLNy/image.png',
  //   needleMinAngle: 0,
  //   needleMaxAngle: 270,
  // ),
  const Dial(
    id: 'classic_colored_dial',
    name: 'Classic',
    style: DialStyle.analog,
    assetType: AssetType.network,
    path: 'https://i.ibb.co/QFtc3pnm/SHARMA-2.png',
    needleMinAngle: 0,
    needleMaxAngle: 240,
  ),
];


/// Hardcoded list of available gauge customization options.
/// Replace the placeholder image paths with actual dial/needle assets.
///
/// Images must be:
///   - Transparent PNGs
///   - Square (1:1 aspect ratio) for both dial and needle
///   - Needle image must point straight up in rest position
final List<GaugeCustomizationOption> kGaugeOptions = [
  // ─── Classic ───
  // GaugeCustomizationOption(
  //   id: 'classic',
  //   dial: _dials[0],
  //   needles: _needles
  // ),
  GaugeCustomizationOption(
    id: 'classic_colored',
    name: "Classic 1",
    dial: _dials[0],
    needles: _needles
  ),

  // ─── Sport ───
  // GaugeCustomizationOption(
  //   id: 'sport',
  //   dial: const Dial(
  //     id: 'sport_dial',
  //     style: DialStyle.analog,
  //     assetType: AssetType.network,
  //     path: 'https://i.ibb.co/whLrrLNy/image.png',
  //     needleMinAngle: 0,
  //     needleMaxAngle: 270,
  //   ),
  //   needles: const [
  //     Needle(
  //       id: 'sport_needle_orange',
  //       assetType: AssetType.network,
  //       path: 'https://i.ibb.co/whLrrLNy/image.png',
  //       color: 'orange',
  //     ),
  //   ],
  // ),

  // // ─── Minimal ───
  // GaugeCustomizationOption(
  //   id: 'minimal',
  //   dial: const Dial(
  //     id: 'minimal_dial',
  //     style: DialStyle.analog,
  //     assetType: AssetType.network,
  //     path: 'https://i.ibb.co/whLrrLNy/image.png',
  //     needleMinAngle: 0,
  //     needleMaxAngle: 270,
  //   ),
  //   needles: const [
  //     Needle(
  //       id: 'minimal_needle',
  //       assetType: AssetType.network,
  //       path: 'https://i.ibb.co/whLrrLNy/image.png',
  //       color: 'white',
  //     ),
  //   ],
  // ),
  //
  // // ─── Neon ───
  // GaugeCustomizationOption(
  //   id: 'neon',
  //   dial: const Dial(
  //     id: 'neon_dial',
  //     style: DialStyle.analog,
  //     assetType: AssetType.network,
  //     path: 'https://i.ibb.co/whLrrLNy/image.png',
  //     needleMinAngle: 0,
  //     needleMaxAngle: 270,
  //   ),
  //   needles: const [
  //     Needle(
  //       id: 'neon_needle_cyan',
  //       assetType: AssetType.network,
  //       path: 'https://i.ibb.co/whLrrLNy/image.png',
  //       color: 'cyan',
  //     ),
  //     Needle(
  //       id: 'neon_needle_magenta',
  //       assetType: AssetType.network,
  //       path: 'https://i.ibb.co/whLrrLNy/image.png',
  //       color: 'magenta',
  //     ),
  //   ],
  // ),
  //
  // // ─── Racing ───
  // GaugeCustomizationOption(
  //   id: 'racing',
  //   dial: const Dial(
  //     id: 'racing_dial',
  //     style: DialStyle.analog,
  //     assetType: AssetType.network,
  //     path: 'https://i.ibb.co/whLrrLNy/image.png',
  //     needleMinAngle: 0,
  //     needleMaxAngle: 270,
  //   ),
  //   needles: const [
  //     Needle(
  //       id: 'racing_needle',
  //       assetType: AssetType.network,
  //       path: 'https://i.ibb.co/whLrrLNy/image.png',
  //       color: 'red',
  //     ),
  //   ],
  // ),
];

/// Returns all unique remote (network) image URLs used by the
/// gauge options. Used by [RemoteAssetService] for pre-warming.
List<String> getAllRemoteAssetUrls() {
  final urls = <String>{};

  void collectFromDial(Dial? dial) {
    if (dial?.assetType == AssetType.network && dial?.path != null) {
      urls.add(dial!.path!);
    }
  }

  void collectFromNeedle(Needle? needle) {
    if (needle?.assetType == AssetType.network && needle?.path != null) {
      urls.add(needle!.path!);
    }
  }

  // Defaults
  collectFromDial(defaultDial);
  collectFromNeedle(defaultNeedle);

  // All standalone needles
  for (final needle in _needles) {
    collectFromNeedle(needle);
  }

  // All dials
  for (final dial in _dials) {
    collectFromDial(dial);
  }

  // All options (in case they reference different assets)
  for (final option in kGaugeOptions) {
    collectFromDial(option.dial);
    if (option.needles != null) {
      for (final needle in option.needles!) {
        collectFromNeedle(needle);
      }
    }
  }

  return urls.toList();
}
