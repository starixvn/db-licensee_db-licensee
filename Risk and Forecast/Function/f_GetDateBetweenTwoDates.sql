/*<info serverAlias="DBEXT-bodb02" selectors="bodbLicenseeNet" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[f_GetDateBetweenTwoDates]
(
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME
)
RETURNS TABLE
AS
RETURN

/*
	Created: 20201022@Kos
	Task: Get dates between 2 dates
	DB: DBEXT.bodb02

	Revisions:
		- 20201022@Kos: Create new [Redmine: #143310]
*/

	SELECT tally.Date
	FROM (
			SELECT	[NoDays] = DATEDIFF(DAY, @FromDate, @ToDate) + 1
		) cnt
		CROSS APPLY (
			SELECT TOP(cnt.NoDays) Date = DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @FromDate)
			FROM (VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x10(n)
				CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x100(n)
				CROSS APPLY	(VALUES (0), (0), (0), (0), (0), (0), (0), (0), (0), (0)) x1000(n)
		) tally

GO