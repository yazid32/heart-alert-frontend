// lib/utils/email_validator.dart
class EmailValidator {
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9](?!.*\.\.)[a-zA-Z0-9._%+-]*@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  
  static final Set<String> _disposableDomains = {
    // Common disposable email domains
    'tempmail.com', 'throwaway.com', 'guerrillamail.com', 'mailinator.com',
    '10minutemail.com', 'temp-mail.org', 'fakeinbox.com', 'yopmail.com',
    'trashmail.com', 'spamgourmet.com', 'mailnator.com', 'guerrillamail.net',
    'guerrillamail.org', 'guerrillamail.biz', 'maildrop.cc', 'mailmetrash.com',
    'temp-mail.net', 'temp-mail.io', 'tempmail.net', 'tempinbox.com',
    'throwawaymail.com', 'trash2009.com', 'trash2010.com', 'trash2011.com',
    'spambox.us', 'spam.la', 'spam.su', 'spamherelots.com', 'spamhereplease.com',
    'spamhole.com', 'spamify.com', 'spaminator.de', 'spamobox.com', 'spamspot.com',
    'tempinbox.co', 'tempinbox.org', 'tempinbox.net', 'tempinbox.info',
    'temp-mail.de', 'temp-mail.ws', 'temp-mail.us', 'temp-mail.org',
    'tempmail.co', 'tempmail.de', 'tempmail.net', 'tempmail.org',
    'tempomail.fr', 'temporary-email.com', 'temporaryemail.net',
    'thankyou2010.com', 'thismail.net', 'trash2009.com', 'trashdevil.com',
    'trashdevil.de', 'trashmail.at', 'trashmail.com', 'trashmail.de',
    'trashmail.io', 'trashmail.me', 'trashmail.net', 'trashmail.org',
    'wegwerfmail.de', 'wegwerfmail.net', 'wegwerfmail.org',
  };
  
  static final Map<String, String> _commonTypos = {
    'gmial.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmil.com': 'gmail.com',
    'gmeil.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'yaho.com': 'yahoo.com',
    'yhoo.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'yahho.com': 'yahoo.com',
    'hotmil.com': 'hotmail.com',
    'hotmal.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'hotmail.co': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outllok.com': 'outlook.com',
    'outlook.co': 'outlook.com',
    'outlook.con': 'outlook.com',
  };
  
  static String? validate(String email) {
    if (email.isEmpty) return 'Email is required';
    
    final trimmed = email.trim().toLowerCase();
    
    // Check format
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    
    final parts = trimmed.split('@');
    final localPart = parts[0];
    final domain = parts[1];
    
    // Check for common typos
    if (_commonTypos.containsKey(domain)) {
      return 'Did you mean ${_commonTypos[domain]}?';
    }
    
    // Check for disposable emails
    if (_disposableDomains.contains(domain)) {
      return 'Please use a permanent email address (disposable emails not allowed)';
    }
    
    // Gmail-specific validation
    if (domain == 'gmail.com') {
      // Check for consecutive dots
      if (localPart.contains('..')) {
        return 'Gmail addresses cannot have consecutive dots';
      }
      
      // Check for local part length (Gmail max is 64 chars)
      if (localPart.length > 64) {
        return 'Email local part is too long (max 64 characters)';
      }
      
      // Check for very short/spammy local parts
      if (localPart.length < 5) {
        // Warn but don't block
        // return null;
      }
      
      // Check for plus addressing - valid but we can store normalized version
      if (localPart.contains('+')) {
        // This is valid Gmail, we'll just note it
        // return null;
      }
    }
    
    // Check for corporate vs personal email (optional)
    final personalDomains = {'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com'};
    if (!personalDomains.contains(domain)) {
      // Professional email - that's good for doctors!
      // You could show a badge or just accept it
    }
    
    return null;
  }
  
  // Normalize email for storage (handles Gmail dot/plus rules)
  static String normalize(String email) {
    final trimmed = email.trim().toLowerCase();
    final parts = trimmed.split('@');
    final localPart = parts[0];
    final domain = parts[1];
    
    if (domain == 'gmail.com') {
      // Remove dots and everything after plus
      String normalized = localPart.split('+')[0].replaceAll('.', '');
      return '$normalized@$domain';
    }
    
    return trimmed;
  }
  
  // Check if email is likely a real professional email (doctors)
  static bool isProfessionalEmail(String email) {
    final professionalDomains = {
      'hospital.com', 'clinic.com', 'medical.org', 'healthcare.com',
      'doctor.com', 'md.com', 'dr.com', 'medicalcenter.com',
    };
    
    final domain = email.split('@')[1];
    return professionalDomains.any((d) => domain.contains(d)) || 
           !_personalDomains.contains(domain);
  }
  
  static final _personalDomains = {
    'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 
    'icloud.com', 'aol.com', 'protonmail.com', 'mail.com'
  };
}