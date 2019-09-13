/*<info serverAlias="DBLIC-bodb_licensee" executers="bodbLicenseeNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Lrf_CheckBelonging_ValidateProduct]
	@productId		INT,
	@licenseeName	VARCHAR(50)
AS
/*
	Created: 20190913@Amanda
	Description: LAP - Check whether product belongs to licensee or not
	DB: DBEXT.bodb02
   
	Revisions:
		- 20190913@Amanda: Create SP[Redmine: #112658]
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT TOP 1 1
	FROM dbo.Licensees l WITH (NOLOCK)
	INNER JOIN dbo.LicenseeProduct3rd lp WITH (NOLOCK) ON l.LicenseeId = lp.LicenseeId
	WHERE l.LicenseeName = @licenseeName AND lp.ProductID = @productId
END
GO