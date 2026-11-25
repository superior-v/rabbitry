import 'package:flutter/material.dart';
import '../services/appearance_service.dart';
export '../services/appearance_service.dart';

/// App-wide color getters — Blue / Pink / Purple theme (Light & Dark aware)
Color get kPrimary => appColor(0xFF7B6BA0, 0xFFB19EEF); // Indigo purple — primary actions
Color get kPink => appColor(0xFFEC4899, 0xFFF472B6); // Pink — feminine accents
Color get kPurple => appColor(0xFF8B5CF6, 0xFFA78BFA); // Purple — secondary accents
Color get kLightTint => appSurface(0xFFEDE9FE, 0xFF252333); // Light purple bg
Color get kSurfaceTint => appSurface(0xFFF0ECFE, 0xFF252333); // Subtle purple surface

/// === PASTEL PALETTE (Light & Crafted Dark Mode) ===
Color get kLilac => appSurface(0xFFC3B1E1, 0xFF352C4C);
Color get kLilacLight => appSurface(0xFFE8DFFA, 0xFF2B263C);
Color get kLilacWash => appSurface(0xFFF5F1FC, 0xFF232030);
Color get kLilacDeep => appColor(0xFF7B6BA0, 0xFFB19EEF);
Color get kLilacText => appColor(0xFF5A4880, 0xFFCFC6E6);

Color get kBluePastel => appSurface(0xFFA8D4F0, 0xFF243348);
Color get kBlueDeep => appColor(0xFF5B8AD0, 0xFF68A8F8);
Color get kBlueLight => appSurface(0xFFD9EEFB, 0xFF202A3A);
Color get kBlueWash => appSurface(0xFFF0F7FD, 0xFF1E2633);
Color get kBlueText => appColor(0xFF4A76B8, 0xFF78B4FA);

Color get kPinkPastel => appSurface(0xFFF2B8C6, 0xFF36232F);
Color get kPinkDeep => appColor(0xFFD4809A, 0xFFF48FB1);
Color get kPinkLight => appSurface(0xFFFADCE5, 0xFF2E202A);
Color get kPinkWash => appSurface(0xFFFDF2F5, 0xFF28202A);
Color get kPinkText => appColor(0xFFB5567A, 0xFFF472B6);

Color get kNeutral900 => appColor(0xFF2C2C2E, 0xFFF1F3F9);
Color get kNeutral800 => appColor(0xFF3A3A3C, 0xFFECEDF4);
Color get kNeutral700 => appColor(0xFF636366, 0xFFB8BDCB);
Color get kNeutral600 => appColor(0xFF8E8E93, 0xFF9EA4B4);
Color get kNeutral500 => appColor(0xFFAEAEB2, 0xFF8C92A4);
Color get kNeutral400 => appColor(0xFFC7C7CC, 0xFF7E8494);
Color get kNeutral300 => appSurface(0xFFE5E5EA, 0xFF2D303E);
Color get kNeutral200 => appSurface(0xFFF2F2F7, 0xFF151720);
Color get kNeutral100 => appSurface(0xFFF9F9FB, 0xFF171922);
Color get kNeutral50 => appSurface(0xFFFCFCFD, 0xFF1E2028);

/// Gender specific colors
Color get kMaleColor => appColor(0xFF5B8AD0, 0xFF68A8F8); // Matches kBlueDeep
Color get kFemaleColor => appColor(0xFFD4809A, 0xFFF48FB1); // Matches kPinkDeep
Color get kHeaderPink => appSurface(0xFFFFBCE7, 0xFF332233); // Soft pastel pink / dark berry-plum
