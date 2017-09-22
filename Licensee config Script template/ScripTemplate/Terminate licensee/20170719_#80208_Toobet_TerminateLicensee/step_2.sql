USE bodb_licensee
GO

/*
	Created: 20170719@Harper	
	Description: Toobet - Terminate licensee
*/
 
DECLARE  @TerminateDate DATE , @PartyID INT

 -- Toobet
SELECT @PartyID = p.PartyID, @TerminateDate = '2017-07-18'
FROM dbo.OAS_Party p WITH (NOLOCK)
WHERE p.PartyName = 'Toobet'

SELECT @TerminateDate, @PartyID  

UPDATE dbo.OAS_ChargeInfo WITH (ROWLOCK, UPDLOCK) 
	SET ToDate = @TerminateDate
		, Remark = 'Terminate licensee #80208'
WHERE FromParty = @PartyID AND ToDate = '2050-01-01'

UPDATE dbo.LA_MinFee WITH(ROWLOCK, UPDLOCK)
	SET ToDate = @TerminateDate
WHERE PartyId = @PartyID AND FeeTypeId = 1 AND ToDate = '2050-01-01'-- Min fee

GO