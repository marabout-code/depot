import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';

class DriverNavigationScreen extends StatelessWidget {
  final OrderModel order;

  const DriverNavigationScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frDeliveryNavigation),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDeliveryTargetCard(context),
          const SizedBox(height: 20),
          _buildQuickActions(context),
          const SizedBox(height: 20),
          _buildCustomerInfoCard(),
          const SizedBox(height: 20),
          _buildOrderSummaryCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDeliveryTargetCard(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on,
                  size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(StringConstants.frDeliverTo,
                style: GoogleFonts.roboto(
                    fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(order.customerName,
                style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            if (order.deliveryAddress != null &&
                order.deliveryAddress!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(order.deliveryAddress!,
                  style: GoogleFonts.roboto(
                      fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
            ],
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${order.totalItems} ${StringConstants.frItemsCount}',
                    style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: Icons.phone,
            label: StringConstants.frCallCustomer,
            color: Colors.green,
            onTap: () {
              if (order.customerPhone != null &&
                  order.customerPhone!.isNotEmpty) {
                launchUrl(Uri.parse('tel:${order.customerPhone}'));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Aucun numéro de téléphone')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionCard(
            icon: Icons.map,
            label: StringConstants.frOpenMaps,
            color: Colors.blue,
            onTap: () {
              final query = order.deliveryAddress ?? order.customerName;
              launchUrl(Uri.parse('https://www.google.com/maps/search/$query'));
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frCustomerDetails,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.person, 'Nom', order.customerName),
            if (order.customerPhone != null &&
                order.customerPhone!.isNotEmpty)
              _infoRow(
                  Icons.phone, 'Téléphone', order.customerPhone!),
            if (order.deliveryAddress != null &&
                order.deliveryAddress!.isNotEmpty)
              _infoRow(Icons.location_on, 'Adresse',
                  order.deliveryAddress!),
            _infoRow(Icons.receipt, 'Commande', order.orderNumber),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frOrderSummary,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('${item.quantity}x',
                              style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(item.productName,
                            style: GoogleFonts.roboto(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: GoogleFonts.roboto(
                    fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.roboto(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
