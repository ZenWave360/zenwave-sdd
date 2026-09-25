# ZDL AsyncAPI Identity and Channel Naming

> Examples use the organization prefix `com.arcadiaeditions`. Replace it with your
> own reverse-domain prefix (`<org>`, from the project overlay) everywhere it
> appears: model ids, plugin ids and packages. These AsyncAPI rules apply to
> microservices. In a modulith, consumers use `@listener` (see the skill, section 7),
> and these rules only apply to events you externalize to a broker.

Use these rules when authoring the AsyncAPI-related parts of a `domain-model.zdl`.
They define only the identifiers, channel ids, and topic names that belong in ZDL.

## Service identity

Derive `<domain>` and `<subdomain>` from the system's architecture identity. Use
lowercase kebab-case for both values.

The ZDL model id identifies the service model:

```zdl
config {
    id "urn:com.arcadiaeditions:<domain>:<subdomain>"
}
```

The AsyncAPI provider plugin id adds `:asyncapi`:

```zdl
ZDLToAsyncAPIPlugin {
    id "urn:com.arcadiaeditions:<domain>:<subdomain>:asyncapi"
}
```

When the ZDL has an AsyncAPI client plugin, its id adds `:asyncapi:client`:

```zdl
ZDLToAsyncAPIClientPlugin {
    id "urn:com.arcadiaeditions:<domain>:<subdomain>:asyncapi:client"
}
```

Keep the same domain and subdomain in all three ids. Do not add a separate service
name segment, environment, message name, or version to these URNs.

Example:

```zdl
config {
    id "urn:com.arcadiaeditions:orders:checkout"

    plugins {
        ZDLToAsyncAPIPlugin {
            id "urn:com.arcadiaeditions:orders:checkout:asyncapi"
            schemaFormat avro
        }
        ZDLToAsyncAPIClientPlugin {
            id "urn:com.arcadiaeditions:orders:checkout:asyncapi:client"
        }
    }
}
```

## Service name used by topics

Build the service name by joining the domain and subdomain with a hyphen:

```text
<domain>-<subdomain>
```

For `urn:com.arcadiaeditions:orders:checkout`, the service name is
`orders-checkout`.

## Message names

Convert the ZDL message type name from PascalCase to kebab-case without changing
its meaning:

| ZDL type | Message name |
| --- | --- |
| `OrderCreated` | `order-created` |
| `AuthorizePayment` | `authorize-payment` |
| `StockReservationConfirmed` | `stock-reservation-confirmed` |

Events should describe facts that have already happened. Commands should describe
actions.

## Channel ids

Use this channel id for both locally declared provider messages and references to
messages from another API:

```text
<message-name>-<message-type>-<version>
```

- `<message-name>` is kebab-case.
- `<message-type>` is `event`, `command`, `response`, `callback`, or `cdc`.
- `<version>` is `v<N>`, such as `v1`.

Examples:

```text
order-created-event-v1
authorize-payment-command-v1
payment-authorized-response-v1
```

Do not use a PascalCase name such as `OrderCreatedChannel`. Do not include the
service name or content type in the channel id.

## Topic names

For a message owned by the current service, use:

```text
<service>.<message-name>.<message-type>.<content-type>.<version>
```

- `<service>` is `<domain>-<subdomain>` in kebab-case.
- `<message-name>`, `<message-type>`, and `<version>` match the channel id.
- `<content-type>` matches the generated payload format, normally `avro` or
  `json`. When `schemaFormat avro` is configured, use `avro`.

Examples:

```text
orders-checkout.order-created.event.avro.v1
payments-processing.authorize-payment.command.avro.v1
payments-processing.payment-authorized.response.json.v1
```

Do not include an environment such as `int`, `pre`, `uat`, or `pro` in the topic.

## ZDL annotations

For a locally declared event, put both the channel id and topic on the event:

```zdl
@asyncapi({
    channel: "order-created-event-v1",
    topic: "orders-checkout.order-created.event.avro.v1"
})
event OrderCreated {
    id Long
    version Integer
}
```

For a service method triggered by a channel from another API, reference the exact
channel id declared by the provider and do not invent a local topic:

```zdl
@asyncapi(api: OrdersCheckoutApi, channel: "order-created-event-v1")
processOrderCreated(OrderCreatedInput) Payment withEvents PaymentAuthorized
```

For a channel owned by the same API, omit `api` but keep the same channel id:

```zdl
@asyncapi(channel: "payment-failed-event-v1")
retryPayment(PaymentFailedInput) Payment withEvents PaymentRetried
```

Client references reuse the provider's channel id exactly. The provider owns the
topic name; a consuming ZDL must not rename or redefine it.

## Consistency checks

Before writing a ZDL file, verify:

- The model id and any provider or client plugin ids use the same domain and
  subdomain.
- Each channel id is `<message-name>-<message-type>-<version>`.
- Each locally owned topic is
  `<domain>-<subdomain>.<message-name>.<message-type>.<content-type>.<version>`.
- The message name, type, and version agree between the channel id and topic.
- Consumed channels exactly match their provider channel ids.
- No topic contains an environment segment.
