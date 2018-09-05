USE bodb_licensee
GO
/*
	Created By: 20170921@Harper
	Description: Delete draf invoice
*/

--SELECT *
--FROM dbo.LA_InvoiceHeader WITH (NOLOCK)
--WHERE InvoiceSymbol = 'Zl CN' AND InvoiceNumber = 6

DELETE dbo.LA_InvoiceStatement
WHERE InvoiceHeaderId = 1922

DELETE dbo.LA_InvoiceHeader
WHERE InvoiceHeaderId = 1922