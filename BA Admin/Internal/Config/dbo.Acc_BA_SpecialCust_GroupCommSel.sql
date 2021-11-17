 set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Acc_BA_SpecialCust_GroupCommSEL]
	(
		@LicenseeID INT ,
		@ErrCode	INT = 0 OUTPUT,		
		@ErrMsg		varchar(1000)='' OUTPUT 
	)
AS
/*
Created: Jim
Date: 5-03-2012
Task : Replace hardcode member spread by web application
DB: DB052.bodb_Licensee
Original:

Revisions:
	
Param's Explanation:
	
*/
SELECT groupa, groupb,groupc, groupd
FROM LicenseeBAConfig (NOLOCK) 
WHERE LicenseeID=@LicenseeID 


GO
GRANT EXECUTE ON [dbo].Acc_BA_SpecialCust_GroupCommSEL TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].Acc_BA_SpecialCust_GroupCommSEL TO [vnteam] 
