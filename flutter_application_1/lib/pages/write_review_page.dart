import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/api_service.dart';

class WriteReviewPage extends StatefulWidget {
  final int    productId;
  final String productName;
  final int?   orderId;
  const WriteReviewPage({
    super.key,
    required this.productId,
    required this.productName,
    this.orderId,
  });
  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  final _commentCtrl = TextEditingController();
  int  _rating  = 0;
  bool _loading = false;

  final _labels = ['', 'Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_rating == 0) {
      _msg("Please select a star rating", error: true); return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.submitReview(
        widget.productId, _rating,
        _commentCtrl.text.trim().isNotEmpty ? _commentCtrl.text.trim() : null,
        orderId: widget.orderId,
      );
      if (!mounted) return;
      _msg("Review submitted! Thank you.");
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _msg(e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _msg(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? AppColors.error : AppColors.success, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: const Text("Write a Review", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.primaryGlow, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_bike_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Reviewing", style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(widget.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ])),
            ]),
          ),
          const SizedBox(height: 32),

          // Star rating
          const Text("YOUR RATING", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 16),
          Center(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _rating = star),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: star <= _rating ? AppColors.warning : AppColors.textMuted,
                    size: 44,
                  ),
                ),
              );
            })),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _rating > 0 ? _labels[_rating] : "Tap to rate",
                key: ValueKey(_rating),
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: _rating > 0 ? AppColors.warning : AppColors.textMuted,
                ),
              ),
            ),
          ])),
          const SizedBox(height: 32),

          // Comment
          const Text("YOUR REVIEW (optional)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 5, maxLength: 500,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: "Share your experience with this product…",
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
                counterStyle: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.star_rounded, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text("Submit Review", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black)),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}
