/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE dbo.Lrf_GetSpecialPlatform
(
	  @SiteName NVARCHAR(50)
)
AS
/*
	Creator: Evan
	Task: LAP - Handle betfrom for Jollysports
	DB: DBEXT-bodb02
	Revision:
		- 20231122@Evan: Initial function [Redmine: #197192]	
		- 20240102@Evan: Support for new SpecialPlatform [Redmine: #198817]	

*/
BEGIN

	SELECT ISNULL(s.SpecialPlatfrom, 0) AS SpecialPlatform
		 , CASE
			   WHEN s.SpecialPlatfrom IN (2, 3) THEN 2
			   ELSE 0
		   END AS SpecialPlatformType
	FROM dbo.Site s WITH (NOLOCK)
	WHERE s.site = @SiteName

END