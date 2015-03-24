ALTER PROCEDURE	dbo.Lrf_3rdProductCheckAllowTab 
	@LicenseeName	VARCHAR(50),
	@ProductId		INT,
	@IsAllowTab		BIT=0				OUTPUT

AS
/*
	Created: 20150309@Winnie
	Task: Check allow enable table 3rd product status of member
	DB: DBLIC/bodb_licensee
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	SELECT @IsAllowTab = 0
	IF EXISTS(
	SELECT TOP 1 1
	  FROM DBTXN.[CustDB].[dbo].[Dep_CustSuper] a
	  INNER JOIN DBTXN.[CustDB].[dbo].Dep_SupperProductSetting b ON a.custid=b.CustID
	  WHERE a.site=@LicenseeName AND b.ProductId=@ProductId)
	BEGIN
	SELECT @IsAllowTab = 1
	END
END

GO
GRANT EXECUTE ON dbo.Lrf_3rdProductCheckAllowTab TO bodbLicenseeNet
GO