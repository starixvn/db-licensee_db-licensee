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

*/
BEGIN

	SELECT CASE
			WHEN s.SpecialPlatfrom = 2 THEN 2
			ELSE 0
		END AS SpecialPlatform
	FROM dbo.Site s WITH (NOLOCK)
	WHERE s.site = @SiteName

END