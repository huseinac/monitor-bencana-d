import 'package:flutter/material.dart';

class AppStyles {
  // btn-primary
  static final ButtonStyle btnPrimary = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF0d6efd),
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  // btn-success
  static final ButtonStyle btnSuccess = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF198754),
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  // btn-danger
  static final ButtonStyle btnDanger = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFdc3545),
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
  static final ButtonStyle btnLogin = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF021E49), 
  
    // border: 2px solid #c1daff
    side: const BorderSide(
      color: Color(0xFFC1DAFF), 
      width: 2,
    ),
    
    // border-radius: 8px
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    
    // Ensure the text color contrasts well
    foregroundColor: Colors.white,
  );
}