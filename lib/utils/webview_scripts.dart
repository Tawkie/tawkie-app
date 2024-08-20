const String clearCookiesAndStorage = """
  (function() {
    // Clear cookies
    var cookies = document.cookie.split(";");
    for (var i = 0; i < cookies.length; i++) {
      var cookie = cookies[i];
      var eqPos = cookie.indexOf("=");
      var name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie;
      document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT;path=/";
    }
    
    // Clear localStorage
    localStorage.clear();
    
    // Clear sessionStorage
    sessionStorage.clear();
  })();
""";

const String declineCookiesMessenger = """
  function declineCookies() {
    var declineButton = document.querySelector('button[data-cookiebanner="accept_only_essential_button"]');
    if (declineButton) {
      declineButton.click();
    }

    var manageDialogAcceptButton = document.querySelector('button[data-testid="cookie-policy-manage-dialog-accept-button"]');
    if (manageDialogAcceptButton) {
      manageDialogAcceptButton.click();
    }
  }
""";

const String declineCookiesInstagram = """
  function declineCookies() {
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        var declineButton = document.querySelector('button[class*="_acan _acap _acaq _acat _acav _aj1- _ap30"]');
        if (declineButton) {
          declineButton.click();
          console.log("Decline button clicked");
          observer.disconnect(); // Stop observing after the button is clicked
        }
      });
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }
""";

const String declineCookiesLinkedin = """
  function declineCookies() {
    var declineButton = document.querySelector('button[action-type="DENY"][data-tracking-control-name="ga-cookie.consent.deny.v4"][data-control-name="ga-cookie.consent.deny.v4"]');
    if (declineButton) {
      declineButton.click();
      console.log("Decline button clicked");
    } else {
      console.log("Decline button not found");
    }
  }
  declineCookies();
""";

const String applyCustomStylesMessenger = """
  function applyCustomStyles() {
    var emailField = document.querySelector('input[name="email"]');
    if (emailField) {
      emailField.style.height = '70px';
      emailField.style.width = '80%';
      emailField.style.fontSize = '32px';
      emailField.style.padding = '14px';
      emailField.style.border = '2px solid #ccc';
      emailField.style.borderRadius = '8px';
      emailField.style.marginBottom = '20px';
    }
  
    var passField = document.querySelector('input[name="pass"]');
    if (passField) {
      passField.style.height = '70px';
      passField.style.width = '80%';
      passField.style.fontSize = '32px';
      passField.style.padding = '14px';
      passField.style.border = '2px solid #ccc';
      passField.style.borderRadius = '8px';
      passField.style.marginBottom = '20px';
    }
  
    var loginButton = document.querySelector('button[name="login"]');
    if (loginButton) {
      loginButton.style.height = '70px';
      loginButton.style.fontSize = '32px';
      loginButton.style.width = '80%';
      loginButton.style.marginTop = '22px';
      loginButton.style.padding = '14px';
      loginButton.style.border = 'none';
      loginButton.style.borderRadius = '8px';
      loginButton.style.backgroundColor = '#007bff';
      loginButton.style.color = '#fff';
    }
  
    var uiInputLabel = document.querySelector('.uiInputLabel.clearfix');
    if (uiInputLabel) {
      uiInputLabel.style.display = 'none';
    }
  
    var specificDiv = document.querySelector('._210n._7mqw');
    if (specificDiv) {
      specificDiv.style.display = 'none';
    }
  
    var imgElement = document.querySelector('img.img');
    if (imgElement) {
      imgElement.setAttribute('style', 'height: 150px !important; width: 150px !important;');
    }
  }
""";

const String replaceDiscordElementContent = """
  function replaceElementContent() {
    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        var element = document.querySelector('h2[data-text-variant="heading-xl/semibold"]');
        if (element) {
          element.textContent = '';
          element.style.marginBottom = '20px';
          console.log("Element content replaced with an empty space and margin added");
          observer.disconnect(); // Stop observing after the element content is replaced
        }
      });
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }
  replaceElementContent();
""";

String getCombinedScriptMessenger() {
  return """
    $declineCookiesMessenger
    $applyCustomStylesMessenger
    declineCookies();
    setTimeout(applyCustomStyles, 50);
  """;
}

String getCombinedScriptInstagram() {
  return """
    $declineCookiesInstagram
    declineCookies();
  """;
}

String getCombinedScriptLinkedin() {
  return """
    $declineCookiesLinkedin
    declineCookies();
  """;
}

String getCombinedScriptDiscord() {
  return """
    $replaceDiscordElementContent
    replaceElementContent();
  """;
}

