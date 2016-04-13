set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go
/*
Lrf_LicenseeCustSel
@LicenseeID=30
*/
ALTER  PROCEDURE [dbo].[Lrf_LicenseeCustSel]
	@LicenseeID INT	
AS

/*
	Created by: [20101207@Henry]
	Task: Get List of Agent below a licensee
	DB: DB052.bodb_Licensee
	Revisions:
	- Replace VND by INH
	- 20130416@Jim: support multi language
	- 20130507@Jim: hard-code to just show licensee description for licensee :1,5,7
	- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function 
	- 20160413@Victor: support MKK currency code
*/

SET NOCOUNT ON
	SELECT 
		l.LicenseeID
		,c.Username
		,l.CustID
		,l.RoleID
		,l.Currency
		,CASE 
			WHEN l.CurrencyName = 'VND' THEN 'INH' 
			WHEN l.CurrencyName = 'MMK' THEN 'MKK' 
			ELSE l.CurrencyName 
		END as CurrencyName
		,CASE WHEN l.licenseeID IN (1,5,7) THEN l.Description ELSE '' END AS Description
		,m.MsgID
	--FROM 
		--LicenseeCust l with (NOLOCK) 
		FROM    bodb_Licensee.dbo.[f_SelLicenseeCust](@LicenseeID) l
		INNER JOIN bodb02.dbo.CustInfo c with (NOLOCK) ON l.CustID = c.CustID AND l.RoleID = c.RoleID
		LEFT JOIN bodb02.dbo.MsgError m WITH (NOLOCK) ON l.Description=m.MsgNameEN
	WHERE LicenseeID = @LicenseeID


GO
GRANT EXECUTE ON [dbo].[Lrf_LicenseeCustSel] TO [bodbLicenseeNet]

GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_LicenseeCustSel] TO [vnteam]


