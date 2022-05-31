# delphi-google-oauth2
Browser enabled TCustomAuthenticator for Delphi TRestClient

This unit is inspired on Delphi's OAuth2 code but:
- Allows authorization via externel browser
- Uses PKCE flow for added security
- Allows gereration of new tokens when they expire (using the refresh token)

# Dependencies
- You will need libeay32.dll and ssleay32.dll in the same folder of your applications's .exe file for the Authenticator to work (becouse PKCE uses SHA256). 
- You will need Indy

# Test authenticator using the demo applicatrion (Google_Email_Example)
Open the project and fill in your Application's ClientID and ClientSecret on procedure googleAPI_prepare:

```pascal
  // Application specific options (created on Google's console)
  DCSOAuth2Authenticator.ClientID              := 'your ClientID goes here';      // ClientID created on console.developers.google.com
  DCSOAuth2Authenticator.ClientSecret          := 'your ClientSecret goes here';  // ClientSecret for the application registered on console.developers.google.com
```
