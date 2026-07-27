import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/qr_receiver_widget.dart';

class ReceiverTabletScreen extends StatefulWidget {
  const ReceiverTabletScreen({super.key});

  @override
  State<ReceiverTabletScreen> createState() => _ReceiverTabletScreenState();
}

class _ReceiverTabletScreenState extends State<ReceiverTabletScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwiftBeamColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: SwiftBeamColors.backgroundAmbientGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Receiver Mode (Web Portal & App Direct)',
                        style: SwiftBeamTypography.headlineMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            flex: 3,
                            child: QRReceiverWidget(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
