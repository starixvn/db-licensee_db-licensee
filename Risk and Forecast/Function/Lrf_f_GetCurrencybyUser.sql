 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER  FUNCTION [dbo].[Lrf_f_GetCurrencybyUser]
(
	@LicenseeID INT ,
	@userID INT ,
	@systemID INT 
)
RETURNS @tmp TABLE (CurrencyID INT, LicenseeID INT, UsrID INT )
AS

 /*
	Created: 20130509@Jim
	Task : Restrict permission of Licensee Users by currency
	DB: DB052.bodb02, DB06.bodb02
	Revisions:	
	20140117@Victor: Grant Select permission for bodbAdminNet
*/
BEGIN 
	INSERT INTO @tmp
	SELECT CurrencyID
		  ,LicenseeID
		  ,UsrID 
	FROM  bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE  usrID=@userID 
		AND LicenseeID=@LicenseeID 
		AND SystemID=@systemID 
		AND isActive=1
	RETURN 
END 	

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetCurrencybyUser] TO [vnteam]
GO
GRANT SELECT ON [dbo].[Lrf_f_GetCurrencybyUser] TO [bodbLicenseeNet]
GO
GRANT SELECT ON [dbo].[Lrf_f_GetCurrencybyUser] TO [bodbAdminNet]
GO

