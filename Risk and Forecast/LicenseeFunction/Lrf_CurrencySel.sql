/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

CREATE PROCEDURE [dbo].[Lrf_CurrencySel]
AS
/*
	Created: 20191021@Amanda
	Description: LAP - Get All Currency Info
	DB: DBEXT.bodb02

	Revisions:
	    - 20191021@Amanda: Add new SP [Redmine: #120333]
		- 20200220@Louis: Cheat currency name for HID Currency [RedmineID: #128816]
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	e.exchangeid AS Id,
			CASE e.exchangeid
				WHEN 20 THEN 'UUS' 
				WHEN 51 THEN 'INH'
				WHEN 70 THEN 'MKK'
				WHEN 75 THEN 'PTU'
				WHEN 76 THEN 'PS'
				WHEN 77 THEN 'PTH'
				WHEN 92 THEN 'HID'
				ELSE e.Code 
			END AS Name
		FROM dbo.Exchange e WITH (NOLOCK)
END
GO

