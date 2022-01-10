/*<info serverAlias="DBTXN-bodb02" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.Lrf_Get_DummyAccount3rd
(
	@LicenseeName VARCHAR(50)
	, @CurrencyId INT = 0
	, @CustId INT = 0 OUTPUT
)
AS
/*
	Created by: 20150601@Patrick
	Task: #36263 - Get dummny account 
	DB: DBTRANS.bodb02
	Revisions: 
		- 20180119@Sophia: Hardcode to get dummy3rd for Spondemo to support testing UAT due to the name spondummy3rdUUS instead of spondemodummy3rdUUS [Redmine: #89808]
		- 20180122@Sophia: Remove workaround (hardcode for Sopndemo). Change the way to get Dummy3rd instead of the formula : LicenseeName + 'dummy3rd' + @CurrencyName [Redmine: #89846]
		- 20211215@Sol: improve performance - [Redmine: #165831]
*/
BEGIN
		
	DECLARE @LicenseeNameNew VARCHAR(50) = NULL

	---get licenseename of special lincensee
	SELECT TOP 1
		@LicenseeNameNew =  LEFT(c.username, CHARINDEX('ACC',c.username) -1)
	FROM custdb.dbo.Customer c WITH(NOLOCK)
		INNER JOIN custdb.dbo.Dep_CustSuper d WITH(NOLOCK)
			ON c.srecommend = d.custid AND c.site = d.site
	WHERE roleid = 3 
		AND c.username LIKE '%ACC%'
		AND c.site <> LEFT(c.username, CHARINDEX('ACC',c.username) -1)
		AND c.site = @LicenseeName
		AND c.currency = @CurrencyId

	SELECT @LicenseeNameNew = CASE WHEN @LicenseeNameNew IS NULL THEN @LicenseeName
									WHEN @LicenseeNameNew = '' THEN @LicenseeName
									ELSE @LicenseeNameNew
								END

	SELECT @CustId = c.CustId
	FROM CustDB.dbo.custInfo c WITH(NOLOCK)
	WHERE c.username LIKE @LicenseeNameNew + 'Dummy3rd%' 
		AND c.roleid = 1
		AND c.mrecommend IN ( 
								SELECT custid 
								FROM CustDB.dbo.custInfo WITH(NOLOCK) 
								WHERE Username LIKE @LicenseeNameNew + 'ACC%' 
									AND Roleid=3 
									AND Currency = @CurrencyId
							)

END
GO