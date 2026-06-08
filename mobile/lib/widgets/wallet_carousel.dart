import 'package:flutter/material.dart';

import '../models/wallet_carousel_item.dart';
import 'wallet_card.dart';

/// Horizontal PageView carousel with peeking credit-card wallet tiles.
class WalletCarousel extends StatefulWidget {
  const WalletCarousel({
    super.key,
    required this.wallets,
  });

  final List<WalletCarouselItem> wallets;

  @override
  State<WalletCarousel> createState() => _WalletCarouselState();
}

class _WalletCarouselState extends State<WalletCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.wallets.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return WalletCard(
                item: widget.wallets[index],
                isDark: isDark,
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_currentPage + 1} / ${widget.wallets.length}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 10),
            Row(
              children: List.generate(
                widget.wallets.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _currentPage == index ? 16 : 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? Colors.grey[700] : Colors.grey[400]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
