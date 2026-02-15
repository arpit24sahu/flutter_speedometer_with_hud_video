import 'package:speedometer/features/labs/models/gauge_customization.dart';


final List<Needle> _needles = [
  Needle(
    id: 'classic_needle_black',
    assetType: AssetType.network,
    path: 'https://i.ibb.co/bMD3KpK0/needle.png',
    color: 'black',
  ),
];

final List<Dial> _dials = [
  const Dial(
    id: 'classic_dial',
    style: DialStyle.analog,
    assetType: AssetType.network,
    path: 'https://i.ibb.co/whLrrLNy/image.png',
    needleMinAngle: 0,
    needleMaxAngle: 270,
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
  GaugeCustomizationOption(
    id: 'classic',
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
