﻿using System;
using System.ComponentModel.DataAnnotations;
using Bit.Core.Enums;
using Bit.Core.Utilities;

namespace Bit.Core.Entities
{
    public class OrganizationApiKey
    {
        public Guid Id { get; set; }
        public Guid OrganizationId { get; set; }
        public OrganizationApiKeyType Type { get; set; }
        [MaxLength(30)]
        public string ApiKey { get; set; }
        public DateTime RevisionDate { get; set; }
    }
}
