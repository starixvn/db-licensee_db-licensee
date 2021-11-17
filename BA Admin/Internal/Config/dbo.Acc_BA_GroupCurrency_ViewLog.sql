/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/ 

USE bodb_CustomerLog
GO

ALTER PROCEDURE [dbo].[Acc_BA_GroupCurrency_ViewLog]
	@LicenseeID		INT = NULL,
	@Currency		INT=NULL,
	@ugroup			varchar(3)=NULL
AS
/*
	Created: Jim
	Date: 20111118
	Task : View BA_GroupCurrency_ViewLog
	DB: DBLOG/bodb_CustomerLog
	Original:

	Revisions:
		- 20111215@jim: Add more view data filter condition 
		- 20180924@Elodie: Migrate bodb_Licensee to DBCUST [Redmine:#99855]
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		A.LicenseeID,
		B.LicenseeName,
		A.Currency,
		CASE WHEN e.exchangeid=20 THEN 'UUS'
			 WHEN e.exchangeid=51 THEN e.currency
			 ELSE e.CODE END AS CurrencyName ,
		A.ugroup,
		C.username AS ModifyBy,
		A.ModifyDate,
		A.IP
	FROM 
		dbo.UserLog_LicenseeCurrencyBAGroup A WITH (NOLOCK)
	INNER JOIN bodb_licensee.dbo.Licensees B WITH (NOLOCK) ON A.LicenseeID = B.LicenseeID
	INNER JOIN bodb02.dbo.Custinfo C WITH (NOLOCK) ON A.ModifyBy = C.CustID
	INNER JOIN bodb02.dbo.exchange e  WITH (NOLOCK) ON A.Currency=e.exchangeid
	WHERE 
		(@LicenseeID=0 OR (@LicenseeID<>0 AND A.LicenseeID = @LicenseeID))
		AND (@ugroup='all' OR (@ugroup<>'all' AND A.ugroup=@ugroup ) )
		AND (@Currency=0 OR (@Currency<>0 AND A.Currency = @Currency) )

	ORDER BY A.LicenseeID, A.ModifyDate DESC
END


 