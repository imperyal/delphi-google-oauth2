program Google_Email_Example;

uses
  Vcl.Forms,
  U_emailExample in 'U_emailExample.pas' {FRM_sendMail},
  U_DCS_OAuth2 in 'U_DCS_OAuth2.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFRM_sendMail, FRM_sendMail);
  Application.Run;
end.
