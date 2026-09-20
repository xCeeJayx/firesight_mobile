import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:firesight_mobile/services/gis_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BarangayRiskPolygon & CFPP Evaluation Tests', () {
    test('Unassessed barangay defaults to gray styling and UNASSESSED badge', () {
      final unassessedBgy = BarangayRiskPolygon(
        name: 'Dulag',
        legalCode: '105522013',
        population: 3556,
        centroid: const LatLng(15.9881, 120.2332),
        polygonPoints: const [
          LatLng(15.9881, 120.2332),
          LatLng(15.9890, 120.2340),
          LatLng(15.9870, 120.2340),
        ],
        riskLevel: 'Unassessed',
        calculatedScore: 0.0,
        cfppStatus: 'Pending Assessment',
        lastAssessed: 'Pending Assessment',
        totalH2HInspected: 1,
        h2hHighRiskCount: 1, // Has an H2H check that was high risk, but CFPP is unassessed!
      );

      expect(unassessedBgy.isAssessed, isFalse);
      expect(unassessedBgy.riskBadgeLabel, equals('UNASSESSED'));
      expect(unassessedBgy.riskColor, equals(const Color(0xFF94A3B8)));
      expect(unassessedBgy.riskFillColor.value, equals(const Color(0xFF64748B).withValues(alpha: 0.10).value));
      expect(unassessedBgy.totalH2HInspected, equals(1));
      expect(unassessedBgy.h2hHighRiskCount, equals(1));
    });

    test('Formulated CFPP High Risk barangay (e.g. Aliwekwek) evaluates to Red', () {
      final highRiskBgy = BarangayRiskPolygon(
        name: 'Aliwekwek',
        legalCode: '105522001',
        population: 1745,
        centroid: const LatLng(15.9686, 120.2458),
        polygonPoints: const [
          LatLng(15.9686, 120.2458),
          LatLng(15.9696, 120.2468),
          LatLng(15.9676, 120.2468),
        ],
        riskLevel: 'High',
        calculatedScore: 64.0,
        cfppStatus: 'Formulated',
        lastAssessed: '2026-08-22',
      );

      expect(highRiskBgy.isAssessed, isTrue);
      expect(highRiskBgy.riskBadgeLabel, equals('HIGH RISK'));
      expect(highRiskBgy.riskColor, equals(const Color(0xFFDC2626)));
    });

    test('Formulated CFPP Low Risk barangay (e.g. Maniboc, Poblacion) evaluates to Green', () {
      final lowRiskBgy = BarangayRiskPolygon(
        name: 'Maniboc',
        legalCode: '105522020',
        population: 4964,
        centroid: const LatLng(16.0315, 120.2185),
        polygonPoints: const [
          LatLng(16.0315, 120.2185),
          LatLng(16.0325, 120.2195),
          LatLng(16.0305, 120.2195),
        ],
        riskLevel: 'Low',
        calculatedScore: 16.0,
        cfppStatus: 'Formulated',
        lastAssessed: '2026-09-10',
      );

      expect(lowRiskBgy.isAssessed, isTrue);
      expect(lowRiskBgy.riskBadgeLabel, equals('LOW RISK'));
      expect(lowRiskBgy.riskColor, equals(const Color(0xFF16A34A)));
    });

    test('Pending assessment with score 0 is strictly not considered assessed', () {
      final pendingBgy = BarangayRiskPolygon(
        name: 'Basing',
        legalCode: '105522007',
        population: 3103,
        centroid: const LatLng(15.9984, 120.2523),
        polygonPoints: const [
          LatLng(15.9984, 120.2523),
          LatLng(15.9994, 120.2533),
          LatLng(15.9974, 120.2533),
        ],
        riskLevel: 'Pending',
        calculatedScore: 0.0,
        cfppStatus: 'Pending Assessment',
        lastAssessed: 'Pending Assessment',
      );

      expect(pendingBgy.isAssessed, isFalse);
      expect(pendingBgy.riskBadgeLabel, equals('UNASSESSED'));
      expect(pendingBgy.riskColor, equals(const Color(0xFF94A3B8)));
    });
  });
}
