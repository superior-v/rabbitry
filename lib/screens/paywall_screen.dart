import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/purchase_service.dart';

class PaywallScreen extends StatefulWidget {
  @override
  _PaywallScreenState createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pets,
                size: 100,
                color: Color(0xFF14B8A6),
              ),
              SizedBox(height: 32),
              Text(
                'Welcome to My Rabbitry',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Manage your rabbitry with ease',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 48),
              _buildFeature('Track breeding tasks and schedules'),
              _buildFeature('Monitor herd health and treatments'),
              _buildFeature('Plan and organize your rabbitry'),
              _buildFeature('View statistics and insights'),
              SizedBox(height: 48),
              Container(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handlePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF14B8A6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Purchase Full Access',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: _handleRestore,
                child: Text(
                  'Restore Purchase',
                  style: TextStyle(
                    color: Color(0xFF14B8A6),
                    fontSize: 16,
                  ),
                ),
              ),

              // 🧪 DEBUG BUTTONS - Remove before production
              SizedBox(height: 40),
              Divider(),
              Text(
                '🧪 Debug Mode',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _simulatePurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text('✅ Simulate Purchase'),
                  ),
                  ElevatedButton(
                    onPressed: _clearPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text('❌ Clear Purchase'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Color(0xFF14B8A6),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);

    try {
      final success = await _purchaseService.buyProduct();

      if (success) {
        await Future.delayed(Duration(seconds: 2));

        if (_purchaseService.isPurchased) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        _showError('Purchase failed. Please try again.');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);

    try {
      await _purchaseService.restorePurchases();

      await Future.delayed(Duration(seconds: 2));

      if (_purchaseService.isPurchased) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showError('No previous purchase found.');
      }
    } catch (e) {
      _showError('Failed to restore purchase: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🧪 DEBUG METHOD - Simulate successful purchase
  Future<void> _simulatePurchase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_purchased', true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Purchase simulated! Restarting app...'),
        backgroundColor: Colors.green,
      ),
    );

    await Future.delayed(Duration(seconds: 1));
    Navigator.of(context).pushReplacementNamed('/home');
  }

  // 🧪 DEBUG METHOD - Clear purchase to see paywall again
  Future<void> _clearPurchase() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_purchased', false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Purchase cleared! Restart app to see paywall.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}